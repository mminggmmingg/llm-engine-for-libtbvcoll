// GPU clock / activity / power from the amdgpu gpu_metrics v3.0 (APU) blob, as tools/probe/gpumetrics_ts.py reads it.

use std::fs;

#[derive(Clone, Copy, Debug, Default)]
pub struct Sample {
    pub t_us: i64,     // CLOCK_MONOTONIC us (the trace clock)
    pub gfx_mhz: u32,  // current gfx clock
    pub gfx_act: u32,  // gfx activity %
    pub socket_w: f32, // socket power
    pub gfx_w: f32,
    pub core_w: f32,      // all cores
    pub core_max_mhz: u32, // fastest core clock
}

#[repr(C)]
struct Timespec {
    tv_sec: i64,
    tv_nsec: i64,
}
extern "C" {
    fn clock_gettime(clk: i32, ts: *mut Timespec) -> i32;
}

/// CLOCK_MONOTONIC in us, the clock ggml_time_us() uses.
pub fn now_us() -> i64 {
    let mut ts = Timespec { tv_sec: 0, tv_nsec: 0 };
    unsafe {
        clock_gettime(1, &mut ts);
    }
    ts.tv_sec * 1_000_000 + ts.tv_nsec / 1000
}

pub fn find_gpu_metrics() -> Option<String> {
    for i in 0..8 {
        let p = format!("/sys/class/drm/card{}/device/gpu_metrics", i);
        if let Ok(b) = fs::read(&p) {
            // format_revision 3 (APU)
            if b.len() > 240 && b[2] == 3 {
                return Some(p);
            }
        }
    }
    None
}

pub fn read_sample(path: &str) -> Option<Sample> {
    let b = fs::read(path).ok()?;
    if b.len() < 240 {
        return None;
    }
    let u16_at = |o: usize| u16::from_le_bytes([b[o], b[o + 1]]) as u32;
    let u32_at = |o: usize| u32::from_le_bytes([b[o], b[o + 1], b[o + 2], b[o + 3]]);
    Some(Sample {
        t_us: now_us(),
        gfx_mhz: u16_at(174),
        gfx_act: u16_at(42),
        socket_w: u32_at(112) as f32 / 1000.0,
        gfx_w: u32_at(124) as f32 / 1000.0,
        core_w: u32_at(132) as f32 / 1000.0,
        core_max_mhz: u16_at(222),
    })
}

pub fn format_sample(s: &Sample) -> String {
    format!("{} {} {} {:.1} {:.1} {:.1} {}", s.t_us, s.gfx_mhz, s.gfx_act, s.socket_w, s.gfx_w, s.core_w, s.core_max_mhz)
}

pub fn parse_sample(l: &str) -> Option<Sample> {
    let v: Vec<&str> = l.split_whitespace().collect();
    if v.len() < 7 {
        return None;
    }
    Some(Sample {
        t_us: v[0].parse().ok()?,
        gfx_mhz: v[1].parse().ok()?,
        gfx_act: v[2].parse().ok()?,
        socket_w: v[3].parse().ok()?,
        gfx_w: v[4].parse().ok()?,
        core_w: v[5].parse().ok()?,
        core_max_mhz: v[6].parse().ok()?,
    })
}

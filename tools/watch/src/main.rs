// inferwatch — watches the 2-node TP inference (the RPC servers' and the client's trace rings, GGML_RPC_TRACE /
// GGML_RPC_TRACE_CLIENT) and, when a run goes idle, writes report.html (A/B timeline incl. data transfer) and receipt.md.
//
//   inferwatch daemon [opts]      watch until stopped; one report per inference session (started by tools/watch/inferwatch.sh)
//   inferwatch snap [opts]        report whatever the rings hold now (last --recs records)
//   inferwatch report <dir>       rebuild the report of a saved session
//   inferwatch agent [opts]       (on B, over ssh) prints the ring count and GPU metrics every 100 ms (gpu_metrics asks the SMU)
//
// options: --out DIR (runs/watch) --a-ring PATH --b-ring PATH --client-ring PATH --b-host USER@HOST --b-bin PATH
//          --idle SECS (3) --recs N (snap: records per ring, 400000)

mod analyze;
mod metrics;
mod report;
mod trace;

use std::collections::VecDeque;
use std::fs;
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

struct Opts {
    out: PathBuf,
    a_ring: String,
    b_ring: String,
    c_ring: String,
    b_host: String,
    b_bin: String,
    idle_s: f64,
    recs: u64,
    rest: Vec<String>,
}

fn opts(args: &[String]) -> Opts {
    let repo = std::env::var("INFERWATCH_REPO")
        .unwrap_or_else(|_| "/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll".into());
    let mut o = Opts {
        out: PathBuf::from(format!("{}/runs/watch", repo)),
        a_ring: "/dev/shm/ggml-rpc-trace-50052.bin".into(),
        b_ring: "/dev/shm/ggml-rpc-trace-50052.bin".into(),
        c_ring: "/dev/shm/ggml-rpc-trace-client.bin".into(),
        b_host: "parks-zbook@10.99.0.2".into(),
        b_bin: "/home/parks-zbook/engine2n/bin/inferwatch".into(),
        idle_s: 3.0,
        recs: 400_000,
        rest: vec![],
    };
    let mut i = 0;
    while i < args.len() {
        let v = || args.get(i + 1).cloned().unwrap_or_default();
        match args[i].as_str() {
            "--out" => { o.out = PathBuf::from(v()); i += 1; }
            "--a-ring" => { o.a_ring = v(); i += 1; }
            "--b-ring" => { o.b_ring = v(); i += 1; }
            "--client-ring" => { o.c_ring = v(); i += 1; }
            "--b-host" => { o.b_host = v(); i += 1; }
            "--b-bin" => { o.b_bin = v(); i += 1; }
            "--idle" => { o.idle_s = v().parse().unwrap_or(3.0); i += 1; }
            "--recs" => { o.recs = v().parse().unwrap_or(400_000); i += 1; }
            s => o.rest.push(s.to_string()),
        }
        i += 1;
    }
    o
}

fn log(msg: &str) {
    let ts = Command::new("date").arg("+%F %T").output().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_default();
    println!("[{}] {}", ts, msg);
    let _ = std::io::stdout().flush();
}

fn stamp() -> String {
    Command::new("date").arg("+%Y%m%d-%H%M%S").output().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_else(|_| "session".into())
}

// ---------------------------------------------------------------------------------------------------------------------
// ring access: local file or B over ssh

fn local_header(path: &str) -> Option<trace::Header> {
    let mut f = fs::File::open(path).ok()?;
    let mut b = vec![0u8; trace::HDR];
    f.read_exact(&mut b).ok()?;
    trace::parse_header(&b)
}

/// header (4096 bytes) + the slots of records [from, to), unwrapped
fn local_slice(path: &str, from: u64, to: u64) -> Option<(Vec<u8>, u64)> {
    let mut f = fs::File::open(path).ok()?;
    let mut hdr = vec![0u8; trace::HDR];
    f.read_exact(&mut hdr).ok()?;
    let h = trace::parse_header(&hdr)?;
    let to = to.min(h.count);
    let from = from.max(to.saturating_sub(h.capacity));
    let mut slots = Vec::new();
    for (off, len) in trace::record_ranges(h.capacity, from, to) {
        let mut b = vec![0u8; len as usize];
        f.seek(SeekFrom::Start(off)).ok()?;
        f.read_exact(&mut b).ok()?;
        slots.extend_from_slice(&b);
    }
    Some(([hdr, slots].concat(), from))
}

fn ssh(host: &str, cmd: &str) -> Option<Vec<u8>> {
    let o = Command::new("ssh").args(["-o", "BatchMode=yes", "-o", "ConnectTimeout=5", host, cmd]).output().ok()?;
    if !o.status.success() {
        return None;
    }
    Some(o.stdout)
}

fn remote_slice(host: &str, path: &str, from: u64, to: u64, capacity: u64) -> Option<(Vec<u8>, u64)> {
    let from = from.max(to.saturating_sub(capacity));
    let mut cmd = format!("dd if={} bs=4096 count=1 status=none", path);
    for (off, len) in trace::record_ranges(capacity, from, to) {
        cmd.push_str(&format!("; dd if={} iflag=skip_bytes,count_bytes skip={} count={} bs=1M status=none", path, off, len));
    }
    let b = ssh(host, &cmd)?;
    if b.len() < trace::HDR {
        return None;
    }
    Some((b, from))
}

fn save_slice(dir: &Path, name: &str, data: &(Vec<u8>, u64)) {
    let mut v = data.0[..trace::HDR].to_vec();
    v.extend_from_slice(&data.1.to_le_bytes());
    v.extend_from_slice(&data.0[trace::HDR..]);
    let _ = fs::write(dir.join(name), v);
}

fn load_slice(path: &Path) -> Option<(trace::Header, Vec<trace::Rec>)> {
    let b = fs::read(path).ok()?;
    if b.len() < trace::HDR + 8 {
        return None;
    }
    let h = trace::parse_header(&b[..trace::HDR])?;
    let from = u64::from_le_bytes(b[trace::HDR..trace::HDR + 8].try_into().unwrap());
    Some((h, trace::parse_records(&b[trace::HDR + 8..], from)))
}

// ---------------------------------------------------------------------------------------------------------------------
// metrics: A sampled here, B from the agent; both kept for the last few minutes

type MetricBuf = Arc<Mutex<VecDeque<metrics::Sample>>>;

fn keep(buf: &MetricBuf, s: metrics::Sample) {
    let mut b = buf.lock().unwrap();
    b.push_back(s);
    while b.len() > 6000 {
        b.pop_front();
    }
}

fn metrics_between(buf: &MetricBuf, t0: i64, t1: i64) -> Vec<metrics::Sample> {
    buf.lock().unwrap().iter().filter(|s| s.t_us >= t0 && s.t_us <= t1).cloned().collect()
}

struct BAgent {
    child: Option<Child>,
    count: Arc<Mutex<(u64, u64, i64)>>, // count, capacity, B host us
    metrics: MetricBuf,
}

fn start_agent(o: &Opts, ag: &mut BAgent) {
    let cmd = format!("{} agent --a-ring {}", o.b_bin, o.b_ring);
    let child = Command::new("ssh")
        .args(["-o", "BatchMode=yes", "-o", "ServerAliveInterval=5", &o.b_host, &cmd])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .spawn();
    let Ok(mut child) = child else {
        log("B 에이전트를 띄우지 못함 (ssh)");
        return;
    };
    let out = child.stdout.take().unwrap();
    let cnt = ag.count.clone();
    let mb = ag.metrics.clone();
    thread::spawn(move || {
        for l in BufReader::new(out).lines().map_while(Result::ok) {
            if let Some(r) = l.strip_prefix("C ") {
                let v: Vec<&str> = r.split_whitespace().collect();
                if v.len() >= 3 {
                    *cnt.lock().unwrap() = (v[0].parse().unwrap_or(0), v[1].parse().unwrap_or(0), v[2].parse().unwrap_or(0));
                }
            } else if let Some(r) = l.strip_prefix("M ") {
                if let Some(s) = metrics::parse_sample(r) {
                    keep(&mb, s);
                }
            }
        }
    });
    ag.child = Some(child);
}

fn deploy_agent(o: &Opts) {
    let me = std::env::current_exe().unwrap();
    let size = fs::metadata(&me).map(|m| m.len()).unwrap_or(0);
    let remote = ssh(&o.b_host, &format!("stat -c %s {} 2>/dev/null || echo 0", o.b_bin))
        .map(|b| String::from_utf8_lossy(&b).trim().parse::<u64>().unwrap_or(0))
        .unwrap_or(0);
    if remote != size {
        let st = Command::new("scp").args(["-q", me.to_str().unwrap(), &format!("{}:{}", o.b_host, o.b_bin)]).status();
        log(&format!("B 에 에이전트 복사: {} ({:?})", o.b_bin, st.map(|s| s.success())));
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// tbv counters: /sys/kernel/debug/thunderbolt_ibverbs/summary is root-only; `inferwatch.sh tbv-copy` (run with sudo on each
// node) keeps a readable copy in /dev/shm/tbv-summary.txt, read at the start and end of every session

const TBV_COPY: &str = "/dev/shm/tbv-summary.txt";

fn tbv_snapshot(o: &Opts, dir: &Path, tag: &str) {
    if let Ok(s) = fs::read_to_string(TBV_COPY) {
        let _ = fs::write(dir.join(format!("tbv_a_{}.txt", tag)), s);
    }
    if let Some(b) = ssh(&o.b_host, &format!("cat {} 2>/dev/null", TBV_COPY)) {
        if !b.is_empty() {
            let _ = fs::write(dir.join(format!("tbv_b_{}.txt", tag)), b);
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// one session -> report

fn build_report(dir: &Path, title: &str, started: &str) -> Option<String> {
    let (ha, ra) = load_slice(&dir.join("a.ring"))?;
    let (hb, rb) = load_slice(&dir.join("b.ring")).unwrap_or((trace::Header::default(), vec![]));
    let rc = load_slice(&dir.join("client.ring")).map(|x| x.1).unwrap_or_default();
    let read_m = |n: &str| -> Vec<metrics::Sample> {
        fs::read_to_string(dir.join(n)).map(|s| s.lines().filter_map(metrics::parse_sample).collect()).unwrap_or_default()
    };
    let n_ar = ra.iter().filter(|r| r.typ == trace::AR || r.typ == trace::AR_SYNC).count();
    if n_ar == 0 && rc.iter().all(|r| r.typ != trace::DECODE) {
        return None;
    }
    let mut an = analyze::analyze(&ra, &rb, &rc, &ha.host, &hb.host, read_m("metrics_a.txt"), read_m("metrics_b.txt"));
    let counters = |f: &str| -> std::collections::HashMap<String, i64> {
        fs::read_to_string(dir.join(f))
            .map(|s| {
                s.lines()
                    .filter_map(|l| {
                        let (k, v) = l.split_once(':')?;
                        Some((k.trim().to_string(), v.trim().parse::<i64>().ok()?))
                    })
                    .collect()
            })
            .unwrap_or_default()
    };
    for n in ["a", "b"] {
        let (s0, s1) = (counters(&format!("tbv_{}_start.txt", n)), counters(&format!("tbv_{}_end.txt", n)));
        if s0.is_empty() || s1.is_empty() {
            continue;
        }
        let mut d: Vec<(String, i64)> = s1.iter().filter_map(|(k, v)| s0.get(k).map(|v0| (k.clone(), v - v0))).collect();
        d.sort();
        an.tbv.push((n.to_uppercase(), d));
    }
    let meta = report::Meta {
        title: title.to_string(),
        started: started.to_string(),
        source: format!("A {} · B {} · 클라이언트 기록 {}", ha.host, if hb.host.is_empty() { "-" } else { &hb.host }, if rc.is_empty() { "없음" } else { "있음" }),
    };
    let rcpt = report::receipt(&an, &meta);
    let _ = fs::write(dir.join("receipt.md"), &rcpt.md);
    let page = report::html(&an, &meta, &rcpt);
    let _ = fs::write(dir.join("report.html"), report::full_document(&page));
    let _ = fs::write(dir.join("report-artifact.html"), page);
    Some(rcpt.summary)
}

fn finish_session(o: &Opts, dir: &Path) {
    let name = dir.file_name().unwrap().to_string_lossy().to_string();
    match build_report(dir, &format!("2노드 추론 기록 {}", name), &name) {
        Some(sum) => {
            let latest = o.out.join("latest");
            let _ = fs::remove_file(&latest);
            let _ = std::os::unix::fs::symlink(fs::canonicalize(dir).unwrap_or(dir.to_path_buf()), &latest);
            log(&format!("보고서: {}/report.html — {}", dir.display(), sum));
        }
        None => log(&format!("{}: AR·decode 기록이 없어 보고서를 만들지 않음 (로딩 등)", name)),
    }
}

// ---------------------------------------------------------------------------------------------------------------------

fn daemon(o: Opts) {
    let _ = fs::create_dir_all(&o.out);
    log(&format!("감시 시작: A {} · 클라이언트 {} · B {}:{} · 쉼 {} s 뒤 보고서 → {}", o.a_ring, o.c_ring, o.b_host, o.b_ring, o.idle_s, o.out.display()));
    deploy_agent(&o);
    let mut ag = BAgent { child: None, count: Arc::new(Mutex::new((0, 0, 0))), metrics: Arc::new(Mutex::new(VecDeque::new())) };
    start_agent(&o, &mut ag);
    // A metrics sampler
    let ma: MetricBuf = Arc::new(Mutex::new(VecDeque::new()));
    {
        let ma = ma.clone();
        thread::spawn(move || {
            let p = metrics::find_gpu_metrics();
            loop {
                if let Some(p) = &p {
                    if let Some(s) = metrics::read_sample(p) {
                        keep(&ma, s);
                    }
                }
                thread::sleep(Duration::from_millis(100));
            }
        });
    }
    let poll = Duration::from_millis(200);
    let cnt = |p: &str| local_header(p).map(|h| h.count).unwrap_or(0);
    let mut last_a = cnt(&o.a_ring);
    let mut last_c = cnt(&o.c_ring);
    let mut idle_b = ag.count.lock().unwrap().0;
    let mut active = false;
    let (mut s_a, mut s_c, mut s_b) = (0u64, 0u64, 0u64);
    let mut t_start = 0i64;
    let mut quiet = 0.0f64;
    let mut seen_a = 0u64; // detect a restarted server (ring recreated)
    let mut last_restart = metrics::now_us();
    let mut session_dir = o.out.join("session");
    loop {
        thread::sleep(poll);
        let agent_done = ag.child.as_mut().map_or(true, |ch| matches!(ch.try_wait(), Ok(Some(_))));
        if agent_done && metrics::now_us() - last_restart > 10_000_000 {
            last_restart = metrics::now_us();
            log("B 에이전트가 끝남 — 다시 띄움");
            deploy_agent(&o);
            start_agent(&o, &mut ag);
        }
        let a = cnt(&o.a_ring);
        let c = cnt(&o.c_ring);
        if a < seen_a {
            last_a = 0; // new server process
        }
        seen_a = a;
        if c < last_c {
            last_c = 0;
        }
        let busy = a.saturating_sub(last_a) >= 20 || c.saturating_sub(last_c) >= 5;
        if !active {
            if busy {
                active = true;
                s_a = last_a.saturating_sub(64);
                s_c = last_c;
                s_b = idle_b.saturating_sub(64);
                t_start = metrics::now_us() - 1_000_000;
                quiet = 0.0;
                session_dir = o.out.join(stamp());
                let _ = fs::create_dir_all(&session_dir);
                tbv_snapshot(&o, &session_dir, "start");
                log("추론 시작 감지");
            } else {
                idle_b = ag.count.lock().unwrap().0;
            }
        } else if busy {
            quiet = 0.0;
        } else {
            quiet += poll.as_secs_f64();
            if quiet >= o.idle_s {
                active = false;
                thread::sleep(Duration::from_millis(300)); // a fresh count from B
                let (e_b, cap_b, _) = *ag.count.lock().unwrap();
                let dir = session_dir.clone();
                tbv_snapshot(&o, &dir, "end");
                if let Some(x) = local_slice(&o.a_ring, s_a, a) {
                    save_slice(&dir, "a.ring", &x);
                }
                if c > s_c {
                    if let Some(x) = local_slice(&o.c_ring, s_c, c) {
                        save_slice(&dir, "client.ring", &x);
                    }
                }
                if e_b > s_b && cap_b > 0 {
                    match remote_slice(&o.b_host, &o.b_ring, s_b, e_b, cap_b) {
                        Some(x) => save_slice(&dir, "b.ring", &x),
                        None => log("B 기록을 가져오지 못함"),
                    }
                }
                let t_end = metrics::now_us();
                let dump = |buf: &MetricBuf, n: &str| {
                    let mut s = String::new();
                    // B samples are on B's clock; take a generous window (the analysis moves them to A's clock)
                    for m in metrics_between(buf, t_start - 600_000_000, t_end + 600_000_000) {
                        s.push_str(&metrics::format_sample(&m));
                        s.push('\n');
                    }
                    let _ = fs::write(dir.join(n), s);
                };
                dump(&ma, "metrics_a.txt");
                dump(&ag.metrics, "metrics_b.txt");
                finish_session(&o, &dir);
                idle_b = e_b;
            }
        }
        last_a = a;
        last_c = c;
    }
}

fn snap(o: Opts) {
    let dir = o.out.join(format!("{}-snap", stamp()));
    let _ = fs::create_dir_all(&dir);
    let a = local_header(&o.a_ring).map(|h| h.count).unwrap_or(0);
    if let Some(x) = local_slice(&o.a_ring, a.saturating_sub(o.recs), a) {
        save_slice(&dir, "a.ring", &x);
    }
    let c = local_header(&o.c_ring).map(|h| h.count).unwrap_or(0);
    if let Some(x) = local_slice(&o.c_ring, c.saturating_sub(o.recs), c) {
        save_slice(&dir, "client.ring", &x);
    }
    if let Some(hb) = ssh(&o.b_host, &format!("dd if={} bs=4096 count=1 status=none", o.b_ring)).and_then(|b| trace::parse_header(&b)) {
        if let Some(x) = remote_slice(&o.b_host, &o.b_ring, hb.count.saturating_sub(o.recs), hb.count, hb.capacity) {
            save_slice(&dir, "b.ring", &x);
        }
    }
    // metrics: one short sample each (the rings hold no metrics)
    if let Some(p) = metrics::find_gpu_metrics() {
        if let Some(s) = metrics::read_sample(&p) {
            let _ = fs::write(dir.join("metrics_a.txt"), metrics::format_sample(&s) + "\n");
        }
    }
    finish_session(&o, &dir);
}

fn agent(o: Opts) {
    let p = metrics::find_gpu_metrics();
    let mut out = std::io::stdout();
    loop {
        let (c, cap) = local_header(&o.a_ring).map(|h| (h.count, h.capacity)).unwrap_or((0, 0));
        if writeln!(out, "C {} {} {}", c, cap, metrics::now_us()).is_err() {
            return;
        }
        if let Some(p) = &p {
            if let Some(s) = metrics::read_sample(p) {
                if writeln!(out, "M {}", metrics::format_sample(&s)).is_err() {
                    return;
                }
            }
        }
        if out.flush().is_err() {
            return;
        }
        thread::sleep(Duration::from_millis(100));
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mode = args.get(1).cloned().unwrap_or_default();
    let o = opts(&args[2.min(args.len())..]);
    match mode.as_str() {
        "daemon" => daemon(o),
        "snap" => snap(o),
        "agent" => agent(o),
        "report" => {
            let Some(d) = o.rest.first() else {
                eprintln!("inferwatch report <session dir>");
                std::process::exit(2);
            };
            let dir = PathBuf::from(d);
            let name = dir.file_name().map(|s| s.to_string_lossy().to_string()).unwrap_or_default();
            match build_report(&dir, &format!("2노드 추론 기록 {}", name), &name) {
                Some(s) => println!("{}/report.html — {}", dir.display(), s),
                None => println!("기록에 AR·decode 가 없음"),
            }
        }
        _ => {
            eprintln!("inferwatch daemon|snap|report <dir>|agent [--out DIR] [--a-ring P] [--b-ring P] [--client-ring P] [--b-host H] [--idle S]");
            std::process::exit(2);
        }
    }
}

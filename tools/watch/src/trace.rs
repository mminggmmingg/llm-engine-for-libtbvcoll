// The trace ring written by ggml-rpc (GGML_RPC_TRACE in a server, GGML_RPC_TRACE_CLIENT in llama-server/llama-bench):
// a 4096-byte header, then `capacity` records of 64 bytes. Record i (0-based, counted since open) lives in slot
// i % capacity and is complete when its idx field equals (i + 1) mod 2^32.

pub const HDR: usize = 4096;
pub const REC: usize = 64;

pub const CMD: u32 = 1; //     a = command;            t: wait start, start, end
pub const AR: u32 = 2; //      a = seq, b = bytes;     t: entry, previous receive done, partial on host, in send buffer, posted, return
pub const AR_SYNC: u32 = 3; // a = seq, b = bytes;     t: entry, previous receive done, partial on host, exchange done, return
pub const GPU: u32 = 4; //     a = seq;                t: GPU ticks copy-out start/end, wait start, peer's flag seen, add end
pub const CAL: u32 = 5; //                             t: host us, GPU tick
pub const RECV: u32 = 6; //    a = seq, b = bytes;     t: receive start, landed
pub const CCMD: u32 = 7; //    a = command, b = endpoint; t: queued, send start, done
pub const ENDP: u32 = 8; //    a = endpoint;           t: endpoint string (48 bytes)
pub const DECODE: u32 = 9; //                          t: llama_decode start, end
pub const UBATCH: u32 = 10; // a = tokens, b = reused; t: start, graph ready, inputs set, compute launched
pub const SYNC: u32 = 11; //                           t: synchronize start, end
pub const PROXY: u32 = 12; //  a = seq, b = bytes;     t: our partial's flag seen, posted, the peer's partial landed (ZC=3 proxy)

pub const CMD_NAMES: [&str; 25] = [
    "ALLOC_BUFFER", "GET_ALIGNMENT", "GET_MAX_SIZE", "BUFFER_GET_BASE", "FREE_BUFFER", "BUFFER_CLEAR", "SET_TENSOR",
    "SET_TENSOR_HASH", "GET_TENSOR", "COPY_TENSOR", "GRAPH_COMPUTE", "GET_DEVICE_MEMORY", "INIT_TENSOR", "GET_ALLOC_SIZE",
    "HELLO", "DEVICE_COUNT", "GRAPH_RECOMPUTE", "MEMSET_TENSOR", "SET_TENSOR_2D", "GET_TENSOR_2D", "COMM_INIT",
    "COMM_ALLREDUCE", "COMM_FREE", "NONE", "ARGMAX_ROWS",
];
pub const CMD_SET_TENSOR: u32 = 6;
pub const CMD_GET_TENSOR: u32 = 8;
pub const CMD_ARGMAX_ROWS: u32 = 24; // the output read since the server-side argmax (2026-11-05), in place of the logits GET_TENSOR

/// A command that reads a step's output: the logits (GET_TENSOR) or their argmax per row (ARGMAX_ROWS).
pub fn is_output_read(cmd: u32) -> bool {
    cmd == CMD_GET_TENSOR || cmd == CMD_ARGMAX_ROWS
}
pub const CMD_GRAPH_COMPUTE: u32 = 10;
pub const CMD_GRAPH_RECOMPUTE: u32 = 16;
pub const CMD_COMM_ALLREDUCE: u32 = 21;

pub fn cmd_name(c: u32) -> &'static str {
    CMD_NAMES.get(c as usize).copied().unwrap_or("?")
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Rec {
    pub typ: u32,
    pub a: u32,
    pub b: u32,
    pub t: [i64; 6],
}

#[derive(Clone, Debug, Default)]
pub struct Header {
    pub capacity: u64,
    pub count: u64,
    pub t_open: i64,
    pub pid: i32,
    pub port: i32,
    pub host: String,
}

fn u32_at(b: &[u8], o: usize) -> u32 {
    u32::from_le_bytes(b[o..o + 4].try_into().unwrap())
}
fn u64_at(b: &[u8], o: usize) -> u64 {
    u64::from_le_bytes(b[o..o + 8].try_into().unwrap())
}
fn i64_at(b: &[u8], o: usize) -> i64 {
    i64::from_le_bytes(b[o..o + 8].try_into().unwrap())
}

pub fn parse_header(b: &[u8]) -> Option<Header> {
    if b.len() < 112 || &b[0..8] != b"GGRPCTR1" || u32_at(b, 12) as usize != REC {
        return None;
    }
    let host = b[48..112].split(|&c| c == 0).next().unwrap_or(&[]);
    Some(Header {
        capacity: u64_at(b, 16),
        count: u64_at(b, 24),
        t_open: i64_at(b, 32),
        pid: u32_at(b, 40) as i32,
        port: u32_at(b, 44) as i32,
        host: String::from_utf8_lossy(host).into_owned(),
    })
}

/// Records with indices [from, to) out of `slots` (raw bytes of consecutive slots starting at slot from % capacity, already
/// unwrapped by the caller), keeping only complete ones.
pub fn parse_records(slots: &[u8], from: u64) -> Vec<Rec> {
    let n = slots.len() / REC;
    let mut out = Vec::with_capacity(n);
    for k in 0..n {
        let o = k * REC;
        let idx = u32_at(slots, o);
        let want = ((from + k as u64 + 1) & 0xffff_ffff) as u32;
        if idx != want {
            continue;
        }
        let mut t = [0i64; 6];
        for (j, v) in t.iter_mut().enumerate() {
            *v = i64_at(slots, o + 16 + 8 * j);
        }
        out.push(Rec { typ: u32_at(slots, o + 4), a: u32_at(slots, o + 8), b: u32_at(slots, o + 12), t });
    }
    out
}

/// Byte ranges (file offsets, lengths) holding records [from, to) of a ring with this capacity (two pieces when it wraps).
pub fn record_ranges(capacity: u64, from: u64, to: u64) -> Vec<(u64, u64)> {
    let mut v = Vec::new();
    if to <= from {
        return v;
    }
    let from = from.max(to.saturating_sub(capacity));
    let s0 = from % capacity;
    let n = to - from;
    let first = n.min(capacity - s0);
    v.push((HDR as u64 + s0 * REC as u64, first * REC as u64));
    if n > first {
        v.push((HDR as u64, (n - first) * REC as u64));
    }
    v
}

/// The endpoint string of an ENDP record.
pub fn endpoint_name(r: &Rec) -> String {
    let mut bytes = Vec::with_capacity(48);
    for v in r.t.iter() {
        bytes.extend_from_slice(&v.to_le_bytes());
    }
    let s = bytes.split(|&c| c == 0).next().unwrap_or(&[]);
    String::from_utf8_lossy(s).into_owned()
}

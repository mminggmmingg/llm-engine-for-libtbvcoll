// Turns the trace records of the two servers (A = the node with the client, B = the peer) and the client into one timeline on
// A's clock, plus the receipt and the data-transfer statistics.
//
// Clocks: every host time is CLOCK_MONOTONIC us of its node. GPU stamps (ticks) go to host us per node by interpolating
// between the (host, tick) calibration pairs. B's host clock goes to A's from the allreduce exchange itself: for the same
// allreduce, (B landed - A sent) = latency A->B + offset and (A landed - B sent) = latency B->A - offset, so per window the
// pair with the smallest sum (round trip) gives offset = half the difference (NTP style).

use crate::metrics::Sample;
use crate::trace::*;
use std::collections::{BTreeMap, HashMap};

// ---------------------------------------------------------------------------------------------------------------------
// categories

pub struct Cat {
    pub name: &'static str,
    pub color: &'static str,
}

pub const C_COMPUTE: u8 = 0;
pub const C_LAUNCH_WAIT: u8 = 1;
pub const C_COPY_ADD: u8 = 2;
pub const C_TURNAROUND: u8 = 3;
pub const C_PEER_WAIT: u8 = 4;
pub const C_STALL: u8 = 5;
pub const C_PREFILL_AR: u8 = 6;
pub const C_H_LAUNCH: u8 = 10;
pub const C_H_PENDING: u8 = 11;
pub const C_H_SYNC: u8 = 12;
pub const C_H_SEND: u8 = 13;
pub const C_H_ENQ: u8 = 14;
pub const C_H_SET: u8 = 15;
pub const C_H_GET: u8 = 16;
pub const C_H_OTHER: u8 = 17;
pub const C_N_SEND: u8 = 20;
pub const C_N_RECV: u8 = 21;
pub const C_N_XCHG: u8 = 22;
pub const C_C_DECODE: u8 = 30;
pub const C_C_GRAPH: u8 = 31;
pub const C_C_INPUTS: u8 = 32;
pub const C_C_LAUNCH: u8 = 33;
pub const C_C_SYNC: u8 = 34;
pub const C_C_OUTSIDE: u8 = 35;
pub const C_Q_WAIT: u8 = 40;
pub const C_Q_SET: u8 = 41;
pub const C_Q_GET: u8 = 42;
pub const C_Q_GRAPH: u8 = 43;
pub const C_Q_AR: u8 = 44;
pub const C_Q_OTHER: u8 = 45;

pub fn cats() -> Vec<(u8, Cat)> {
    vec![
        (C_COMPUTE, Cat { name: "GPU 계산 (부분그래프 커널 + 커널 사이)", color: "#4e79a7" }),
        (C_LAUNCH_WAIT, Cat { name: "GPU 쉼: 다음 부분그래프 발행 전", color: "#f28e2b" }),
        (C_COPY_ADD, Cat { name: "부분합 복사·더하기", color: "#9d9d9d" }),
        (C_TURNAROUND, Cat { name: "GPU 쉼: 호스트가 깨어나 보내고 기다림 커널 넣기", color: "#edc948" }),
        (C_PEER_WAIT, Cat { name: "GPU 쉼: 상대 부분합 기다림", color: "#b07aa1" }),
        (C_STALL, Cat { name: "상대 부분합이 1 ms 넘게 늦음 (링크 멈춤)", color: "#e15759" }),
        (C_PREFILL_AR, Cat { name: "큰 AR 교환 (prefill, GPU 기록 없음)", color: "#76b7b2" }),
        (C_H_LAUNCH, Cat { name: "서버: 부분그래프 받아 커널 발행", color: "#59a14f" }),
        (C_H_PENDING, Cat { name: "서버 AR: 이전 받기 마무리", color: "#9c755f" }),
        (C_H_SYNC, Cat { name: "서버 AR: GPU 끝 기다림", color: "#cfcfcf" }),
        (C_H_SEND, Cat { name: "서버 AR: 부분합 보내기", color: "#ff9da7" }),
        (C_H_ENQ, Cat { name: "서버 AR: 기다림·더하기 커널 넣기", color: "#d7b5a6" }),
        (C_H_SET, Cat { name: "서버: SET_TENSOR (입력)", color: "#86bcb6" }),
        (C_H_GET, Cat { name: "서버: GET_TENSOR (출력)", color: "#f1ce63" }),
        (C_H_OTHER, Cat { name: "서버: 기타 명령", color: "#79706e" }),
        (C_N_SEND, Cat { name: "보내기 (버퍼에 넣고 post)", color: "#ff9da7" }),
        (C_N_RECV, Cat { name: "받기 스레드 (받기 시작 → 도착)", color: "#a0cbe8" }),
        (C_N_XCHG, Cat { name: "큰 AR 주고받기 (prefill)", color: "#76b7b2" }),
        (C_C_DECODE, Cat { name: "클라이언트: llama_decode 안 (기타)", color: "#bcd7ee" }),
        (C_C_GRAPH, Cat { name: "클라이언트: 그래프 준비 (재사용/빌드·할당)", color: "#f28e2b" }),
        (C_C_INPUTS, Cat { name: "클라이언트: 입력 설정", color: "#86bcb6" }),
        (C_C_LAUNCH, Cat { name: "클라이언트: 계산 발행 (sched, 서버로 명령)", color: "#59a14f" }),
        (C_C_SYNC, Cat { name: "클라이언트: 결과 기다림 (synchronize)", color: "#cfcfcf" }),
        (C_C_OUTSIDE, Cat { name: "클라이언트: decode 밖 (샘플링·앱)", color: "#e15759" }),
        (C_Q_WAIT, Cat { name: "명령: 보내기 대기열", color: "#e6e6e6" }),
        (C_Q_SET, Cat { name: "명령: SET_TENSOR", color: "#86bcb6" }),
        (C_Q_GET, Cat { name: "명령: GET_TENSOR", color: "#f1ce63" }),
        (C_Q_GRAPH, Cat { name: "명령: GRAPH_(RE)COMPUTE", color: "#59a14f" }),
        (C_Q_AR, Cat { name: "명령: COMM_ALLREDUCE", color: "#b07aa1" }),
        (C_Q_OTHER, Cat { name: "명령: 기타", color: "#79706e" }),
    ]
}

// ---------------------------------------------------------------------------------------------------------------------
// per node records

#[derive(Clone, Copy, Debug)]
pub struct ArRec {
    pub seq: u32,
    pub bytes: u32,
    pub sync: bool, // the large-partial path (prefill)
    pub entry: f64,
    pub pending: f64,
    pub ready: f64,
    pub copied: f64,
    pub sent: f64, // posted (sync path: exchange done)
    pub end: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct CmdRec {
    pub cmd: u32,
    pub wait: f64,
    pub start: f64,
    pub end: f64,
}

#[derive(Default)]
pub struct Node {
    pub name: String,
    pub host: String,
    pub ars: Vec<ArRec>,                     // in record order
    pub ar_by_seq: HashMap<u32, usize>,      // zero-copy / overlap allreduces
    pub gpu: HashMap<u32, [f64; 5]>,         // host us (converted)
    pub recv: HashMap<u32, (f64, f64, u32)>, // receive start, landed, bytes
    pub cmds: Vec<CmdRec>,
    pub cal: Vec<(f64, f64)>, // (tick, host us)
    pub gpu_raw: HashMap<u32, [i64; 5]>,
}

fn conv_fn(cal: &[(f64, f64)]) -> impl Fn(f64) -> f64 + '_ {
    move |tick: f64| {
        if cal.is_empty() {
            return f64::NAN;
        }
        if cal.len() == 1 {
            return cal[0].1 + (tick - cal[0].0) * 0.01;
        }
        let i = match cal.binary_search_by(|p| p.0.partial_cmp(&tick).unwrap()) {
            Ok(i) => return cal[i].1,
            Err(i) => i,
        };
        let (a, b) = if i == 0 {
            (cal[0], cal[1])
        } else if i >= cal.len() {
            (cal[cal.len() - 2], cal[cal.len() - 1])
        } else {
            (cal[i - 1], cal[i])
        };
        let slope = (b.1 - a.1) / (b.0 - a.0);
        a.1 + (tick - a.0) * slope
    }
}

impl Node {
    pub fn from_records(name: &str, host: &str, recs: &[Rec]) -> Node {
        let mut n = Node { name: name.to_string(), host: host.to_string(), ..Default::default() };
        for r in recs {
            let t = |i: usize| r.t[i] as f64;
            match r.typ {
                CMD => n.cmds.push(CmdRec { cmd: r.a, wait: t(0), start: t(1), end: t(2) }),
                AR => {
                    let ar = ArRec {
                        seq: r.a,
                        bytes: r.b,
                        sync: false,
                        entry: t(0),
                        pending: t(1),
                        ready: t(2),
                        copied: t(3),
                        sent: t(4),
                        end: t(5),
                    };
                    n.ar_by_seq.insert(r.a, n.ars.len());
                    n.ars.push(ar);
                }
                AR_SYNC => n.ars.push(ArRec {
                    seq: r.a,
                    bytes: r.b,
                    sync: true,
                    entry: t(0),
                    pending: t(1),
                    ready: t(2),
                    copied: t(2),
                    sent: t(3),
                    end: t(4),
                }),
                GPU => {
                    if r.t[..5].iter().all(|&v| v > 0) {
                        n.gpu_raw.insert(r.a, [r.t[0], r.t[1], r.t[2], r.t[3], r.t[4]]);
                    }
                }
                CAL => {
                    if r.t[0] > 0 && r.t[1] > 0 {
                        n.cal.push((t(1), t(0)));
                    }
                }
                RECV => {
                    n.recv.insert(r.a, (t(0), t(1), r.b));
                }
                _ => {}
            }
        }
        n.cal.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        n.cal.dedup_by(|a, b| a.0 == b.0);
        let gpu = {
            let conv = conv_fn(&n.cal);
            let mut gpu = HashMap::new();
            for (&q, g) in n.gpu_raw.iter() {
                gpu.insert(q, [conv(g[0] as f64), conv(g[1] as f64), conv(g[2] as f64), conv(g[3] as f64), conv(g[4] as f64)]);
            }
            gpu
        };
        n.gpu = gpu;
        n.cmds.sort_by(|a, b| a.start.partial_cmp(&b.start).unwrap());
        n
    }

    /// Move every host time of this node by -off(t) (B to A's clock).
    pub fn shift(&mut self, off: &dyn Fn(f64) -> f64) {
        let f = |t: f64| if t > 0.0 { t - off(t) } else { t };
        for a in self.ars.iter_mut() {
            a.entry = f(a.entry);
            a.pending = f(a.pending);
            a.ready = f(a.ready);
            a.copied = f(a.copied);
            a.sent = f(a.sent);
            a.end = f(a.end);
        }
        for g in self.gpu.values_mut() {
            for v in g.iter_mut() {
                *v = f(*v);
            }
        }
        for r in self.recv.values_mut() {
            r.0 = f(r.0);
            r.1 = f(r.1);
        }
        for c in self.cmds.iter_mut() {
            c.wait = f(c.wait);
            c.start = f(c.start);
            c.end = f(c.end);
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// client

#[derive(Default)]
pub struct Client {
    pub decodes: Vec<(f64, f64)>,
    pub ubatches: Vec<(u32, bool, [f64; 4])>,
    pub syncs: Vec<(f64, f64)>,
    pub ccmds: Vec<(u32, u32, f64, f64, f64)>, // cmd, endpoint, queued, send, done
    pub endpoints: HashMap<u32, String>,
}

impl Client {
    pub fn from_records(recs: &[Rec]) -> Client {
        let mut c = Client::default();
        for r in recs {
            let t = |i: usize| r.t[i] as f64;
            match r.typ {
                DECODE => c.decodes.push((t(0), t(1))),
                UBATCH => c.ubatches.push((r.a, r.b != 0, [t(0), t(1), t(2), t(3)])),
                SYNC => c.syncs.push((t(0), t(1))),
                CCMD => c.ccmds.push((r.a, r.b, t(0), t(1), t(2))),
                ENDP => {
                    c.endpoints.insert(r.a, endpoint_name(r));
                }
                _ => {}
            }
        }
        c.decodes.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        c
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// output

pub struct Row {
    pub name: String,
    pub segs: Vec<(f64, f64, u8)>, // start (A us), duration, category
}

pub struct Link {
    pub t0: f64,
    pub t1: f64,
    pub a_to_b: bool,
    pub bytes: u32,
}

pub struct Step {
    pub start: f64,
    pub end: f64,
    pub tokens: u32,
    pub prefill: bool,
}

pub struct DirStats {
    pub name: String,
    pub n: usize,
    pub bytes: u64,
    pub lat: Vec<f64>,  // sent -> landed on the peer (us)
    pub send: Vec<f64>, // ready -> posted
    pub recv: Vec<f64>, // receive start -> landed (peer side)
    pub stalls: usize,
    pub stall_us: f64,
}

pub struct Analysis {
    pub t0: f64,
    pub t1: f64,
    pub rows: Vec<Row>,
    pub links: Vec<Link>,
    pub steps: Vec<Step>,
    pub dirs: Vec<DirStats>,
    pub sync_xchg: Vec<(u32, f64)>, // large allreduces: bytes, exchange time (us), node A
    pub metrics: Vec<(String, Vec<Sample>)>,
    pub notes: Vec<String>,
    pub seq_shift: i64,
    pub offset_us: f64,
    pub cal_points: (usize, usize),
    /// step boundary chain: (name, samples in us) per decode step
    pub boundary: Vec<(String, Vec<f64>)>,
    /// tbv counter increments over the session per node (filled by the caller when snapshots exist)
    pub tbv: Vec<(String, Vec<(String, i64)>)>,
}

fn median(v: &mut Vec<f64>) -> f64 {
    if v.is_empty() {
        return f64::NAN;
    }
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    v[v.len() / 2]
}

pub fn pct(v: &[f64], p: f64) -> f64 {
    if v.is_empty() {
        return f64::NAN;
    }
    let mut s = v.to_vec();
    s.sort_by(|a, b| a.partial_cmp(b).unwrap());
    s[((p / 100.0) * (s.len() - 1) as f64).round() as usize]
}

/// Seq shift (B's seq = A's seq + shift) and the B - A clock offset samples (A time, offset).
/// Shift: for the right pairing, the one-way delay (B landed - A sent) changes little from one allreduce to the next
/// (latency jitter); a wrong pairing adds cycle-length differences. (The round-trip sum cannot tell: it reduces to each
/// node's own times.) Offset: per window of 32 allreduces (~10 ms; the host clocks can be slewed by NTP/chrony right
/// after a boot, tens of ms over a minute), the pair with the smallest round trip.
fn align(a: &Node, b: &Node, notes: &mut Vec<String>) -> (i64, Vec<(f64, f64)>) {
    let zc: Vec<&ArRec> = a.ars.iter().filter(|x| !x.sync).collect();
    let mid = zc.len() / 2;
    let part = &zc[mid.saturating_sub(1500)..(mid + 1500).min(zc.len())];
    let d1 = |q: u32, s: i64| -> Option<f64> {
        let qb = (q as i64 + s) as u32;
        let ia = a.ar_by_seq.get(&q)?;
        let rb = b.recv.get(&qb)?;
        Some(rb.1 - a.ars[*ia].sent)
    };
    let mut best: Option<(i64, f64)> = None;
    let mut scores = Vec::new();
    for s in -8i64..=8 {
        let mut dd = Vec::new();
        for ar in part.iter() {
            if let (Some(x), Some(y)) = (d1(ar.seq, s), d1(ar.seq + 1, s)) {
                dd.push((y - x).abs());
            }
        }
        if dd.len() < 16 {
            continue;
        }
        let m = median(&mut dd);
        scores.push(format!("{:+}:{:.0}", s, m));
        if best.map_or(true, |(_, bm)| m < bm) {
            best = Some((s, m));
        }
    }
    let Some((shift, jit)) = best else {
        notes.push("A·B 의 같은 AR 을 짝짓지 못함 — B 시각은 A 시계로 옮기지 않음(노드 사이 정렬 없음)".into());
        return (0, vec![]);
    };
    notes.push(format!(
        "AR 짝: B seq = A seq {:+} (이웃 AR 사이 한 방향 지연 변화 중앙 {:.1} us; 후보 {})",
        shift,
        jit,
        scores.join(" ")
    ));
    let mut pairs: Vec<(f64, f64, f64)> = Vec::new(); // (A time, round trip, offset)
    for ar in zc.iter() {
        let qb = (ar.seq as i64 + shift) as u32;
        let (Some(ra), Some(&ib), Some(rb)) = (a.recv.get(&ar.seq), b.ar_by_seq.get(&qb), b.recv.get(&qb)) else {
            continue;
        };
        let br = &b.ars[ib];
        let x1 = rb.1 - ar.sent; // A->B latency + off
        let x2 = ra.1 - br.sent; // B->A latency - off
        pairs.push((ar.sent, x1 + x2, (x1 - x2) / 2.0));
    }
    pairs.sort_by(|x, y| x.0.partial_cmp(&y.0).unwrap());
    let mut out = Vec::new();
    let mut rtts = Vec::new();
    for w in pairs.chunks(32) {
        let p = w.iter().min_by(|x, y| x.1.partial_cmp(&y.1).unwrap()).unwrap();
        out.push((p.0, p.2));
        rtts.push(p.1);
    }
    notes.push(format!("노드 사이 시계: 창(AR 32개) {}개, 창마다 고른 왕복 중앙 {:.1} us", out.len(), median(&mut rtts)));
    (shift, out)
}

fn interp(pts: &[(f64, f64)], t: f64) -> f64 {
    if pts.is_empty() {
        return 0.0;
    }
    if pts.len() == 1 || t <= pts[0].0 {
        return pts[0].1;
    }
    if t >= pts[pts.len() - 1].0 {
        return pts[pts.len() - 1].1;
    }
    let i = pts.partition_point(|p| p.0 <= t);
    let (a, b) = (pts[i - 1], pts[i]);
    a.1 + (b.1 - a.1) * (t - a.0) / (b.0 - a.0)
}

fn push(row: &mut Row, s: f64, e: f64, c: u8) {
    if s.is_finite() && e.is_finite() && e > s {
        row.segs.push((s, e - s, c));
    }
}

/// The GPU row of a node: per allreduce, the subgraph before it (with the time before its first launch) and the exchange.
fn gpu_row(n: &Node) -> Row {
    let mut row = Row { name: format!("{} GPU", n.name), segs: vec![] };
    // launches (GRAPH_RECOMPUTE / GRAPH_COMPUTE) by start time
    let launches: Vec<f64> = n
        .cmds
        .iter()
        .filter(|c| c.cmd == CMD_GRAPH_RECOMPUTE || c.cmd == CMD_GRAPH_COMPUTE)
        .map(|c| c.start)
        .collect();
    let mut prev_end: Option<f64> = None; // GPU add end of the previous zero-copy allreduce
    let mut prev_host_end: Option<f64> = None;
    for ar in n.ars.iter() {
        if let (false, Some(g)) = (ar.sync, n.gpu.get(&ar.seq)) {
            if let Some(pe) = prev_end {
                if g[0] > pe && g[0] - pe < 1.0e6 {
                    // the last launch that started before this allreduce's command
                    let i = launches.partition_point(|&s| s <= ar.entry);
                    let launch = if i > 0 { launches[i - 1] } else { pe };
                    let lw = (launch - pe).clamp(0.0, g[0] - pe);
                    push(&mut row, pe, pe + lw, C_LAUNCH_WAIT);
                    push(&mut row, pe + lw, g[0], C_COMPUTE);
                }
            }
            push(&mut row, g[0], g[1], C_COPY_ADD);
            push(&mut row, g[1], g[2], C_TURNAROUND);
            push(&mut row, g[2], g[3], if g[3] - g[2] > 1000.0 { C_STALL } else { C_PEER_WAIT });
            push(&mut row, g[3], g[4], C_COPY_ADD);
            prev_end = Some(g[4]);
        } else {
            // no GPU stamps: host-side estimate (subgraph until the partial was on the host, then the exchange)
            if let Some(pe) = prev_host_end.or(prev_end) {
                push(&mut row, pe, ar.ready, C_COMPUTE);
            }
            push(&mut row, ar.ready, ar.end, C_PREFILL_AR);
            prev_end = None;
        }
        prev_host_end = Some(ar.end);
    }
    row.segs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
    row
}

fn host_row(n: &Node) -> Row {
    let mut row = Row { name: format!("{} 서버 스레드", n.name), segs: vec![] };
    let mut ai = 0usize;
    let mut ars: Vec<&ArRec> = n.ars.iter().collect();
    ars.sort_by(|a, b| a.entry.partial_cmp(&b.entry).unwrap());
    for c in n.cmds.iter() {
        match c.cmd {
            CMD_COMM_ALLREDUCE => {
                while ai < ars.len() && ars[ai].entry < c.start - 1.0 {
                    ai += 1;
                }
                if ai < ars.len() && ars[ai].entry <= c.end + 1.0 {
                    let a = ars[ai];
                    push(&mut row, c.start, a.pending, C_H_PENDING);
                    push(&mut row, a.pending, a.ready, C_H_SYNC);
                    push(&mut row, a.ready, a.sent, C_H_SEND);
                    push(&mut row, a.sent, c.end, C_H_ENQ);
                    ai += 1;
                } else {
                    push(&mut row, c.start, c.end, C_H_OTHER);
                }
            }
            CMD_GRAPH_RECOMPUTE | CMD_GRAPH_COMPUTE => push(&mut row, c.start, c.end, C_H_LAUNCH),
            CMD_SET_TENSOR => push(&mut row, c.start, c.end, C_H_SET),
            CMD_GET_TENSOR => push(&mut row, c.start, c.end, C_H_GET),
            _ => push(&mut row, c.start, c.end, C_H_OTHER),
        }
    }
    row.segs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
    row
}

fn net_row(n: &Node) -> Row {
    let mut row = Row { name: format!("{} 보내기·받기", n.name), segs: vec![] };
    for a in n.ars.iter() {
        if a.sync {
            push(&mut row, a.ready, a.sent, C_N_XCHG);
        } else {
            push(&mut row, a.ready, a.sent, C_N_SEND);
        }
    }
    for r in n.recv.values() {
        push(&mut row, r.0, r.1, C_N_RECV);
    }
    row.segs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
    row
}

fn client_rows(c: &Client) -> Vec<Row> {
    let mut dec = Row { name: "클라이언트 (A) decode".into(), segs: vec![] };
    for (i, d) in c.decodes.iter().enumerate() {
        push(&mut dec, d.0, d.1, C_C_DECODE);
        if let Some(n) = c.decodes.get(i + 1) {
            if n.0 - d.1 < 5.0e6 {
                push(&mut dec, d.1, n.0, C_C_OUTSIDE);
            }
        }
    }
    for (_, _, t) in c.ubatches.iter() {
        push(&mut dec, t[0], t[1], C_C_GRAPH);
        push(&mut dec, t[1], t[2], C_C_INPUTS);
        push(&mut dec, t[2], t[3], C_C_LAUNCH);
    }
    for s in c.syncs.iter() {
        push(&mut dec, s.0, s.1, C_C_SYNC);
    }
    dec.segs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
    let mut rows = vec![dec];
    // command rows per endpoint name (several dispatchers may share one endpoint)
    let mut by_name: BTreeMap<String, Row> = BTreeMap::new();
    for &(cmd, ep, q, s, d) in c.ccmds.iter() {
        let ename = c.endpoints.get(&ep).cloned().unwrap_or_else(|| format!("endpoint {}", ep));
        let label = if ename.starts_with("127.") || ename.starts_with("localhost") {
            format!("클라이언트 → A 명령 ({})", ename)
        } else {
            format!("클라이언트 → B 명령 ({})", ename)
        };
        let row = by_name.entry(label.clone()).or_insert(Row { name: label, segs: vec![] });
        push(row, q, s, C_Q_WAIT);
        let cat = match cmd {
            CMD_SET_TENSOR => C_Q_SET,
            CMD_GET_TENSOR => C_Q_GET,
            CMD_GRAPH_COMPUTE | CMD_GRAPH_RECOMPUTE => C_Q_GRAPH,
            CMD_COMM_ALLREDUCE => C_Q_AR,
            _ => C_Q_OTHER,
        };
        push(row, s, d, cat);
    }
    for (_, mut r) in by_name {
        r.segs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        rows.push(r);
    }
    rows
}

pub fn analyze(a_recs: &[Rec], b_recs: &[Rec], c_recs: &[Rec], a_host: &str, b_host: &str, metrics_a: Vec<Sample>,
        metrics_b: Vec<Sample>) -> Analysis {
    let mut notes = Vec::new();
    let a = Node::from_records("A", a_host, a_recs);
    let mut b = Node::from_records("B", b_host, b_recs);
    let client = Client::from_records(c_recs);
    if a.cal.len() < 2 || b.cal.len() < 2 {
        notes.push(format!(
            "GPU↔호스트 시계 맞춤 쌍이 적음 (A {}, B {}) — 1쌍이면 100 MHz 로 가정",
            a.cal.len(),
            b.cal.len()
        ));
    }
    let (shift, offs) = align(&a, &b, &mut notes);
    let off0 = if offs.is_empty() { 0.0 } else { offs[offs.len() / 2].1 };
    if !offs.is_empty() {
        let lo = offs.iter().map(|x| x.1).fold(f64::INFINITY, f64::min);
        let hi = offs.iter().map(|x| x.1).fold(f64::NEG_INFINITY, f64::max);
        notes.push(format!(
            "B 시계 - A 시계: {:.3} … {:.3} s (기록 동안 {:.1} ms 움직임 — 호스트 시계 보정(NTP) 때문, 창 사이는 선형 보간)",
            lo / 1e6,
            hi / 1e6,
            (hi - lo) / 1e3
        ));
    }
    // B host time -> A: x = tb - off(x) (off is a function of A time; two passes are plenty)
    let offs_ref = offs.clone();
    let off_b = move |tb: f64| {
        let mut x = tb - interp(&offs_ref, tb - off0);
        x = tb - interp(&offs_ref, x);
        tb - x
    };
    b.shift(&off_b);
    let mb: Vec<Sample> = metrics_b
        .into_iter()
        .map(|mut s| {
            s.t_us -= off_b(s.t_us as f64) as i64;
            s
        })
        .collect();

    // time range: the allreduces and the client's decodes
    let mut t0 = f64::INFINITY;
    let mut t1 = f64::NEG_INFINITY;
    for n in [&a, &b] {
        for x in n.ars.iter() {
            t0 = t0.min(x.entry);
            t1 = t1.max(x.end);
        }
    }
    for d in client.decodes.iter() {
        t0 = t0.min(d.0);
        t1 = t1.max(d.1);
    }
    if !t0.is_finite() {
        t0 = 0.0;
        t1 = 1.0;
    }
    t0 -= 200.0;
    t1 += 200.0;

    // rows: client on top, then A (thread, GPU, net), then B mirrored (net, GPU, thread)
    let mut rows = client_rows(&client);
    rows.retain(|r| !r.segs.is_empty());
    rows.push(host_row(&a));
    rows.push(gpu_row(&a));
    rows.push(net_row(&a));
    rows.push(net_row(&b));
    rows.push(gpu_row(&b));
    rows.push(host_row(&b));
    for r in rows.iter_mut() {
        r.segs.retain(|s| s.0 + s.1 >= t0 && s.0 <= t1);
    }

    // data transfer: links and per direction statistics
    let mut links = Vec::new();
    let mut dab = DirStats { name: "A → B".into(), n: 0, bytes: 0, lat: vec![], send: vec![], recv: vec![], stalls: 0, stall_us: 0.0 };
    let mut dba = DirStats { name: "B → A".into(), n: 0, bytes: 0, lat: vec![], send: vec![], recv: vec![], stalls: 0, stall_us: 0.0 };
    for ar in a.ars.iter().filter(|x| !x.sync) {
        let qb = (ar.seq as i64 + shift) as u32;
        if let Some(rb) = b.recv.get(&qb) {
            links.push(Link { t0: ar.sent, t1: rb.1, a_to_b: true, bytes: ar.bytes });
            dab.n += 1;
            dab.bytes += ar.bytes as u64;
            dab.lat.push(rb.1 - ar.sent);
            dab.send.push(ar.sent - ar.ready);
            dab.recv.push(rb.1 - rb.0);
        }
    }
    for br in b.ars.iter().filter(|x| !x.sync) {
        let qa = (br.seq as i64 - shift) as u32;
        if let Some(ra) = a.recv.get(&qa) {
            links.push(Link { t0: br.sent, t1: ra.1, a_to_b: false, bytes: br.bytes });
            dba.n += 1;
            dba.bytes += br.bytes as u64;
            dba.lat.push(ra.1 - br.sent);
            dba.send.push(br.sent - br.ready);
            dba.recv.push(ra.1 - ra.0);
        }
    }
    // the stalls: a GPU waited > 1 ms for the peer's partial (counted on the waiting node: that direction was late)
    for (n, d) in [(&a, &mut dba), (&b, &mut dab)] {
        for g in n.gpu.values() {
            if g[3] - g[2] > 1000.0 {
                d.stalls += 1;
                d.stall_us += g[3] - g[2];
            }
        }
    }
    links.retain(|l| l.t0 >= t0 && l.t0 <= t1);
    links.sort_by(|x, y| x.t0.partial_cmp(&y.t0).unwrap());
    let sync_xchg: Vec<(u32, f64)> = a.ars.iter().filter(|x| x.sync).map(|x| (x.bytes, x.sent - x.ready)).collect();

    // steps: llama_decode calls (client), else the outputs read (GET_TENSOR) on A
    let mut steps = Vec::new();
    if client.decodes.len() >= 2 {
        for (i, d) in client.decodes.iter().enumerate() {
            let tokens: u32 = client.ubatches.iter().filter(|u| u.2[0] >= d.0 && u.2[0] <= d.1).map(|u| u.0).sum();
            let end = client.decodes.get(i + 1).map(|n| n.0).unwrap_or(d.1);
            if end - d.0 > 5.0e6 {
                continue; // idle gap between requests
            }
            steps.push(Step { start: d.0, end, tokens, prefill: tokens > 16 });
        }
    } else {
        let gets: Vec<f64> = a.cmds.iter().filter(|c| c.cmd == CMD_GET_TENSOR).map(|c| c.end).collect();
        for w in gets.windows(2) {
            if w[1] - w[0] < 5.0e6 {
                steps.push(Step { start: w[0], end: w[1], tokens: 1, prefill: false });
            }
        }
        notes.push("클라이언트 기록이 없어 decode 단계는 A 의 GET_TENSOR(출력 읽기) 사이로 나눔".into());
    }

    let boundary = boundary_chain(&a, &b, &client, &steps);

    Analysis {
        boundary,
        tbv: vec![],
        t0,
        t1,
        rows,
        links,
        steps,
        dirs: vec![dab, dba],
        sync_xchg,
        metrics: vec![("A".into(), metrics_a), ("B".into(), mb)],
        notes,
        seq_shift: shift,
        offset_us: off0,
        cal_points: (a.cal.len(), b.cal.len()),
    }
}

/// What happens between two decode steps, per step: the output layer (each server's GET_TENSOR waits for it, then sends the
/// logits), when each node's logits reach the client, the client's own time (sampling, app) until the next llama_decode, and
/// from llama_decode until each server starts launching the first subgraph (inputs in between).
fn boundary_chain(a: &Node, b: &Node, c: &Client, steps: &[Step]) -> Vec<(String, Vec<f64>)> {
    let gets = |n: &Node| -> Vec<CmdRec> { n.cmds.iter().filter(|x| x.cmd == CMD_GET_TENSOR).cloned().collect() };
    let launches = |n: &Node| -> Vec<f64> {
        n.cmds.iter().filter(|x| x.cmd == CMD_GRAPH_RECOMPUTE || x.cmd == CMD_GRAPH_COMPUTE).map(|x| x.start).collect()
    };
    let (ga, gb, la, lb) = (gets(a), gets(b), launches(a), launches(b));
    let is_a = |ep: u32| c.endpoints.get(&ep).map_or(false, |e| e.starts_with("127.") || e.starts_with("localhost"));
    let mut cga: Vec<f64> = c.ccmds.iter().filter(|x| x.0 == CMD_GET_TENSOR && is_a(x.1)).map(|x| x.4).collect();
    let mut cgb: Vec<f64> = c.ccmds.iter().filter(|x| x.0 == CMD_GET_TENSOR && !is_a(x.1)).map(|x| x.4).collect();
    cga.sort_by(|x, y| x.partial_cmp(y).unwrap());
    cgb.sort_by(|x, y| x.partial_cmp(y).unwrap());
    let before = |v: &[f64], t: f64| -> Option<f64> {
        let i = v.partition_point(|&x| x < t);
        if i > 0 { Some(v[i - 1]) } else { None }
    };
    let after = |v: &[f64], t: f64| -> Option<f64> { v.get(v.partition_point(|&x| x < t)).copied() };
    let get_before = |g: &[CmdRec], t: f64| -> Option<CmdRec> {
        let i = g.partition_point(|x| x.start < t);
        if i > 0 { Some(g[i - 1]) } else { None }
    };
    let names = [
        "출력층 + 로짓 보내기 (A 서버 GET_TENSOR)",
        "출력층 + 로짓 보내기 (B 서버 GET_TENSOR)",
        "B 로짓이 A 로짓보다 늦게 도착 (클라이언트)",
        "마지막 로짓 도착 → 다음 llama_decode (샘플링·앱)",
        "llama_decode → A 서버 첫 부분그래프 발행",
        "llama_decode → B 서버 첫 부분그래프 발행",
    ];
    let mut out: Vec<(String, Vec<f64>)> = names.iter().map(|n| (n.to_string(), Vec::new())).collect();
    for s in steps.iter().filter(|s| !s.prefill) {
        let d0 = s.start;
        let (Some(xa), Some(xb), Some(ca), Some(cb), Some(fa), Some(fb)) = (
            get_before(&ga, d0),
            get_before(&gb, d0),
            before(&cga, d0),
            before(&cgb, d0),
            after(&la, d0),
            after(&lb, d0),
        ) else {
            continue;
        };
        if d0 - xa.start > 50_000.0 || fa - d0 > 50_000.0 {
            continue; // between requests
        }
        out[0].1.push(xa.end - xa.start);
        out[1].1.push(xb.end - xb.start);
        out[2].1.push(cb - ca);
        out[3].1.push(d0 - ca.max(cb));
        out[4].1.push(fa - d0);
        out[5].1.push(fb - d0);
    }
    out
}

/// Time of each category of a row inside [s, e) (segments of one row may overlap — client phases sit inside the decode).
pub fn row_time_in(row: &Row, s: f64, e: f64, acc: &mut HashMap<u8, f64>) {
    // rows are sorted by start; segments are short except client spans, so scan from a little before s
    let i0 = row.segs.partition_point(|x| x.0 < s - 6.0e6);
    for x in row.segs[i0..].iter() {
        if x.0 >= e {
            break;
        }
        let a = x.0.max(s);
        let b = (x.0 + x.1).min(e);
        if b > a {
            *acc.entry(x.2).or_insert(0.0) += b - a;
        }
    }
}

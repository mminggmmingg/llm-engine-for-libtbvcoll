// receipt.md (+ the same tables in the page) and report.html (A/B timeline, data transfer, GPU clocks)

use crate::analyze::*;
use std::collections::HashMap;
use std::fmt::Write;

pub struct Meta {
    pub title: String,
    pub started: String,
    pub source: String,
}

fn esc(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;")
}

fn js_str(s: &str) -> String {
    let mut o = String::from("\"");
    for ch in s.chars() {
        match ch {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '<' => o.push_str("\\u003c"),
            c if (c as u32) < 0x20 => {
                let _ = write!(o, "\\u{:04x}", c as u32);
            }
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

fn f1(v: f64) -> String {
    if v.is_finite() {
        format!("{:.1}", v)
    } else {
        "-".into()
    }
}
fn f2(v: f64) -> String {
    if v.is_finite() {
        format!("{:.2}", v)
    } else {
        "-".into()
    }
}

struct Table {
    head: Vec<String>,
    rows: Vec<Vec<String>>,
}

impl Table {
    fn md(&self) -> String {
        let mut s = format!("| {} |\n|", self.head.join(" | "));
        for (i, _) in self.head.iter().enumerate() {
            s.push_str(if i == 0 { "---|" } else { "---:|" });
        }
        s.push('\n');
        for r in self.rows.iter() {
            let _ = writeln!(s, "| {} |", r.join(" | "));
        }
        s
    }
    fn html(&self) -> String {
        let mut s = String::from("<table><thead><tr>");
        for h in self.head.iter() {
            let _ = write!(s, "<th>{}</th>", esc(h));
        }
        s.push_str("</tr></thead><tbody>");
        for r in self.rows.iter() {
            s.push_str("<tr>");
            for (i, c) in r.iter().enumerate() {
                let bold = c.starts_with("**");
                let c2 = c.trim_matches('*');
                if i == 0 {
                    let _ = write!(s, "<td>{}</td>", if bold { format!("<b>{}</b>", esc(c2)) } else { esc(c2) });
                } else {
                    let _ = write!(s, "<td class=n>{}</td>", if bold { format!("<b>{}</b>", esc(c2)) } else { esc(c2) });
                }
            }
            s.push_str("</tr>");
        }
        s.push_str("</tbody></table>");
        s
    }
}

pub struct Receipt {
    pub md: String,
    pub html: String,
    pub summary: String,
}

fn row_by_name<'a>(an: &'a Analysis, name: &str) -> Option<&'a Row> {
    an.rows.iter().find(|r| r.name == name)
}

pub fn receipt(an: &Analysis, meta: &Meta) -> Receipt {
    let catlist = cats();
    let cname: HashMap<u8, &str> = catlist.iter().map(|(i, c)| (*i, c.name)).collect();
    let dec: Vec<&Step> = an.steps.iter().filter(|s| !s.prefill).collect();
    let pre: Vec<&Step> = an.steps.iter().filter(|s| s.prefill).collect();
    let n_dec = dec.len().max(1) as f64;
    let dec_us: f64 = dec.iter().map(|s| s.end - s.start).sum();
    let dec_tokens: u32 = dec.iter().map(|s| s.tokens.max(1)).sum();
    let mut md = String::new();
    let mut html = String::new();
    let mut summary = String::new();

    let _ = writeln!(md, "# 추론 영수증 — {}\n", meta.title);
    let _ = writeln!(md, "- 시작 {} · 기록 길이 {:.2} s · 출처 {}", meta.started, (an.t1 - an.t0) / 1e6, meta.source);
    let tps = if dec_us > 0.0 { dec_tokens as f64 / (dec_us / 1e6) } else { f64::NAN };
    let _ = writeln!(
        md,
        "- decode 단계 {}개 (토큰 {}개) · 단계당 {} ms · **{} tok/s** (decode 단계 시간 기준) · prefill 단계 {}개 (토큰 {}개, {:.1} ms)",
        dec.len(),
        dec_tokens,
        f2(dec_us / n_dec / 1000.0),
        f1(tps),
        pre.len(),
        pre.iter().map(|s| s.tokens).sum::<u32>(),
        pre.iter().map(|s| s.end - s.start).sum::<f64>() / 1000.0
    );
    let _ = write!(summary, "{} decode 단계 · {} ms/단계 · {} tok/s", dec.len(), f2(dec_us / n_dec / 1000.0), f1(tps));
    md.push('\n');

    // GPU per node
    let gpu_cats = [C_COMPUTE, C_LAUNCH_WAIT, C_TURNAROUND, C_PEER_WAIT, C_STALL, C_COPY_ADD, C_PREFILL_AR];
    let mut per_node: Vec<HashMap<u8, f64>> = Vec::new();
    for n in ["A", "B"] {
        let mut acc = HashMap::new();
        if let Some(r) = row_by_name(an, &format!("{} GPU", n)) {
            for s in dec.iter() {
                row_time_in(r, s.start, s.end, &mut acc);
            }
        }
        per_node.push(acc);
    }
    let step_ms = dec_us / n_dec / 1000.0;
    let mut t = Table { head: vec!["GPU (decode 한 단계당)".into(), "A ms".into(), "A %".into(), "B ms".into(), "B %".into()], rows: vec![] };
    for &c in gpu_cats.iter() {
        let a = per_node[0].get(&c).copied().unwrap_or(0.0) / n_dec / 1000.0;
        let b = per_node[1].get(&c).copied().unwrap_or(0.0) / n_dec / 1000.0;
        if a == 0.0 && b == 0.0 {
            continue;
        }
        t.rows.push(vec![cname[&c].to_string(), f2(a), f1(a / step_ms * 100.0), f2(b), f1(b / step_ms * 100.0)]);
    }
    let sa: f64 = per_node[0].values().sum::<f64>() / n_dec / 1000.0;
    let sb: f64 = per_node[1].values().sum::<f64>() / n_dec / 1000.0;
    t.rows.push(vec![
        "GPU 기록 없는 시간 (첫·끝 AR 밖, 큰 AR 사이)".into(),
        f2(step_ms - sa),
        f1((step_ms - sa) / step_ms * 100.0),
        f2(step_ms - sb),
        f1((step_ms - sb) / step_ms * 100.0),
    ]);
    t.rows.push(vec!["**합 (단계 길이)**".into(), f2(step_ms), "100".into(), f2(step_ms), "100".into()]);
    let _ = writeln!(md, "## decode 한 단계(토큰)당 시간 — 노드별 GPU\n\n{}", t.md());
    let _ = write!(html, "<h3>decode 한 단계(토큰)당 시간 — 노드별 GPU</h3>{}", t.html());

    // client
    let crow = an.rows.iter().find(|r| r.name.starts_with("클라이언트 (A) decode"));
    if let Some(cr) = crow {
        let mut acc = HashMap::new();
        for s in dec.iter() {
            row_time_in(cr, s.start, s.end, &mut acc);
        }
        let g = |c: u8| acc.get(&c).copied().unwrap_or(0.0) / n_dec / 1000.0;
        // llama_decode only launches the step; the wait for its results (synchronize) comes after it returns
        let dec_call = g(C_C_DECODE);
        let phases = g(C_C_GRAPH) + g(C_C_INPUTS) + g(C_C_LAUNCH);
        let sync = g(C_C_SYNC);
        let mut t = Table { head: vec!["클라이언트 (A, decode 한 단계당)".into(), "ms".into(), "%".into()], rows: vec![] };
        t.rows.push(vec!["**llama_decode 호출 (단계 시작)**".into(), f2(dec_call), f1(dec_call / step_ms * 100.0)]);
        for c in [C_C_GRAPH, C_C_INPUTS, C_C_LAUNCH] {
            t.rows.push(vec![format!("  {}", cname[&c]), f2(g(c)), f1(g(c) / step_ms * 100.0)]);
        }
        t.rows.push(vec!["  호출 안 기타".into(), f2(dec_call - phases), f1((dec_call - phases) / step_ms * 100.0)]);
        t.rows.push(vec![format!("**{}**", cname[&C_C_SYNC]), f2(sync), f1(sync / step_ms * 100.0)]);
        let rest = step_ms - dec_call - sync;
        t.rows.push(vec!["**그 밖 (출력 읽기 뒤 샘플링·앱·다음 단계 준비)**".into(), f2(rest), f1(rest / step_ms * 100.0)]);
        let _ = writeln!(md, "## 클라이언트 (A)\n\n{}", t.md());
        let _ = write!(html, "<h3>클라이언트 (A)</h3>{}", t.html());
    }

    // step boundary
    if an.boundary.iter().any(|(_, v)| !v.is_empty()) {
        let mut t = Table {
            head: vec!["단계 사이 (decode 단계마다, us)".into(), "중앙".into(), "p10".into(), "p90".into()],
            rows: vec![],
        };
        for (n, v) in an.boundary.iter() {
            t.rows.push(vec![n.clone(), f1(pct(v, 50.0)), f1(pct(v, 10.0)), f1(pct(v, 90.0))]);
        }
        let _ = writeln!(md, "## 단계 사이 (GPU 가 다음 단계를 기다리는 동안)\n\n{}", t.md());
        let _ = write!(html, "<h3>단계 사이 (GPU 가 다음 단계를 기다리는 동안)</h3>{}", t.html());
    }

    // data transfer
    let mut t = Table {
        head: vec![
            "데이터 전송 (decode AR)".into(),
            "메시지".into(),
            "평균 바이트".into(),
            "지연 p10 / 중앙 / p90 / p99 / 최대 (us)".into(),
            "보내기 중앙 (us)".into(),
            "받기 스레드 중앙 (us)".into(),
            "1 ms 넘게 늦음".into(),
        ],
        rows: vec![],
    };
    for d in an.dirs.iter() {
        let maxv = d.lat.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        t.rows.push(vec![
            d.name.clone(),
            d.n.to_string(),
            if d.n > 0 { format!("{}", d.bytes / d.n as u64) } else { "-".into() },
            format!("{} / {} / {} / {} / {}", f1(pct(&d.lat, 10.0)), f1(pct(&d.lat, 50.0)), f1(pct(&d.lat, 90.0)), f1(pct(&d.lat, 99.0)), f1(maxv)),
            f1(pct(&d.send, 50.0)),
            f1(pct(&d.recv, 50.0)),
            format!("{}번, {:.2} ms/단계", d.stalls, d.stall_us / n_dec / 1000.0),
        ]);
    }
    let _ = writeln!(md, "## 데이터 전송\n\n{}", t.md());
    let _ = writeln!(
        md,
        "지연 = 보낸 쪽이 post 를 마친 시각 → 받는 쪽 받기 스레드가 부분합을 다 받은 시각(노드 사이 시계는 AR 왕복으로 맞춤). 1 ms 넘게 늦음 = 받는 쪽 GPU 가 그만큼 기다린 AR.\n"
    );
    let _ = write!(html, "<h3>데이터 전송</h3>{}<p class=note>지연 = 보낸 쪽 post 끝 → 받는 쪽 받기 스레드가 다 받은 시각 (노드 사이 시계는 AR 왕복으로 맞춤). '1 ms 넘게 늦음' = 받는 쪽 GPU 가 그만큼 기다린 AR.</p>", t.html());
    if !an.sync_xchg.is_empty() {
        let n = an.sync_xchg.len();
        let bytes: f64 = an.sync_xchg.iter().map(|x| x.0 as f64).sum::<f64>() / n as f64;
        let times: Vec<f64> = an.sync_xchg.iter().map(|x| x.1).collect();
        let tm = pct(&times, 50.0);
        let mut t = Table {
            head: vec!["큰 AR (prefill)".into(), "개수".into(), "평균 바이트".into(), "주고받기 중앙 (us)".into(), "실효 GB/s (한 방향)".into()],
            rows: vec![],
        };
        t.rows.push(vec!["A 기준".into(), n.to_string(), format!("{:.0}", bytes), f1(tm), f2(bytes / tm / 1000.0)]);
        let _ = writeln!(md, "{}", t.md());
        let _ = write!(html, "{}", t.html());
    }

    // tbv counters (when the session has snapshots)
    if !an.tbv.is_empty() {
        let keys = [
            ("data_wr_send", "보낸 WR"),
            ("data_wr_rnr_retransmit", "RNR 뒤 다시 보냄"),
            ("data_rx_ack_rnr", "받은 RNR (상대가 받을 자리 없음)"),
            ("data_rx_rnr", "보낸 RNR (내가 받을 자리 없음)"),
            ("data_wr_no_recv_credit", "받기 credit 없이 보냄"),
            ("data_wr_retransmit", "시간 초과 뒤 다시 보냄"),
            ("data_rx_reorder_buffered", "순서 맞추려 잡아 둠"),
        ];
        let mut t = Table { head: vec!["tbv 카운터 (세션 동안 늘어난 값)".into()], rows: vec![] };
        for (n, _) in an.tbv.iter() {
            t.head.push(format!("{} 합", n));
            t.head.push(format!("{} /단계", n));
        }
        for (k, label) in keys {
            let mut row = vec![format!("{} ({})", label, k)];
            for (_, d) in an.tbv.iter() {
                let v = d.iter().find(|x| x.0 == k).map(|x| x.1).unwrap_or(0);
                row.push(v.to_string());
                row.push(f2(v as f64 / n_dec));
            }
            t.rows.push(row);
        }
        let _ = writeln!(md, "## 링크 (tbv)\n\n{}", t.md());
        let _ = write!(html, "<h3>링크 (tbv)</h3>{}", t.html());
    }

    // ZC=3: where the waits over 1 ms came from
    if !an.stalls.is_empty() {
        let names = [
            "상대 서버가 그 부분그래프를 늦게 발행 (상대 GPU 가 놀았음)",
            "상대 GPU 가 늦게 끝냄 (앞 AR 이 늦게 풀렸거나 계산이 길었음)",
            "링크 (상대는 제때 보냈는데 늦게 도착)",
            "상대 대리 스레드가 부분합을 보고도 늦게 보냄",
        ];
        let mut cnt = [0usize; 4];
        let mut sum = [0f64; 4];
        let mut comp: [Vec<f64>; 6] = Default::default();
        for st in an.stalls.iter() {
            // the largest of: the peer's partial ready late, its proxy posting late, the link
            let k = if st.peer_post_delay >= st.peer_late.max(st.link) {
                3
            } else if st.link >= st.peer_late {
                2
            } else if st.peer_launch_late > 0.5 * st.peer_late {
                0
            } else {
                1
            };
            cnt[k] += 1;
            sum[k] += st.wait;
            comp[0].push(st.wait);
            comp[1].push(st.peer_late);
            comp[2].push(st.link);
            comp[3].push(st.peer_launch_late);
            comp[4].push(st.peer_compute - st.our_compute);
            comp[5].push(st.peer_post_delay);
        }
        let tot: f64 = sum.iter().sum();
        let mut t = Table { head: vec!["1 ms 넘는 기다림의 원인 (ZC=3, decode 단계)".into(), "번".into(), "기다림 ms/단계".into(), "%".into()], rows: vec![] };
        for k in 0..4 {
            t.rows.push(vec![names[k].into(), cnt[k].to_string(), f2(sum[k] / n_dec / 1000.0), f1(sum[k] / tot.max(1.0) * 100.0)]);
        }
        let _ = writeln!(md, "## 1 ms 넘는 기다림의 원인\n\n{}", t.md());
        let _ = writeln!(
            md,
            "중앙값(us): 기다림 {} · 상대 부분합이 우리보다 늦게 준비된 몫 {} · 상대 대리 스레드 보내기 지연 {} · 링크 {} · 상대 GPU 가 발행을 기다린 몫 {} · 그 구간 계산 (상대 − 우리) {}. \
            A 가 기다린 것 {}번, B 가 기다린 것 {}번, 그 노드의 decode 단계 첫 AR 인 것 {}번.\n",
            f1(pct(&comp[0], 50.0)), f1(pct(&comp[1], 50.0)), f1(pct(&comp[5], 50.0)), f1(pct(&comp[2], 50.0)), f1(pct(&comp[3], 50.0)),
            f1(pct(&comp[4], 50.0)),
            an.stalls.iter().filter(|x| x.waiter == 0).count(), an.stalls.iter().filter(|x| x.waiter == 1).count(),
            an.stalls.iter().filter(|x| x.first_in_step).count()
        );
        let _ = write!(html, "<h3>1 ms 넘는 기다림의 원인</h3>{}", t.html());
    }

    // ranked waste
    let mut waste: Vec<(String, f64)> = Vec::new();
    for c in [C_LAUNCH_WAIT, C_TURNAROUND, C_PEER_WAIT, C_STALL] {
        let v = (per_node[0].get(&c).copied().unwrap_or(0.0) + per_node[1].get(&c).copied().unwrap_or(0.0)) / 2.0 / n_dec / 1000.0;
        if v > 0.0 {
            waste.push((cname[&c].to_string(), v));
        }
    }
    waste.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    let mut t = Table { head: vec!["GPU 가 쉰 시간 (두 노드 평균, 큰 순)".into(), "ms/단계".into(), "%".into()], rows: vec![] };
    for (n, v) in waste.iter() {
        t.rows.push(vec![n.clone(), f2(*v), f1(v / step_ms * 100.0)]);
    }
    let _ = writeln!(md, "## 줄일 곳 (GPU 가 쉰 시간)\n\n{}", t.md());
    let _ = write!(html, "<h3>줄일 곳 (GPU 가 쉰 시간)</h3>{}", t.html());

    // record quality
    let _ = writeln!(md, "## 기록\n");
    let _ = write!(html, "<h3>기록</h3><ul class=note>");
    for n in an.notes.iter() {
        let _ = writeln!(md, "- {}", n);
        let _ = write!(html, "<li>{}</li>", esc(n));
    }
    let _ = writeln!(md, "- GPU↔호스트 맞춤 쌍: A {}, B {}", an.cal_points.0, an.cal_points.1);
    let _ = write!(html, "<li>GPU↔호스트 맞춤 쌍: A {}, B {}</li></ul>", an.cal_points.0, an.cal_points.1);
    Receipt { md, html, summary }
}

/// The detail window: the whole run if it is small enough, else consecutive decode steps around the middle holding at most
/// `limit` segments (the overview and the receipt still cover the whole run).
fn detail_window(an: &Analysis, limit: usize) -> (f64, f64) {
    let count = |w0: f64, w1: f64| -> usize {
        an.rows
            .iter()
            .map(|r| {
                let a = r.segs.partition_point(|x| x.0 < w0);
                let b = r.segs.partition_point(|x| x.0 <= w1);
                b.saturating_sub(a)
            })
            .sum()
    };
    if count(an.t0, an.t1) <= limit {
        return (an.t0, an.t1);
    }
    let st: Vec<&Step> = an.steps.iter().collect();
    if st.is_empty() {
        let w = (an.t1 - an.t0) * limit as f64 / count(an.t0, an.t1) as f64;
        let c = (an.t0 + an.t1) / 2.0;
        return (c - w / 2.0, c + w / 2.0);
    }
    let mid = st.len() / 2;
    let (mut i, mut j) = (mid, mid);
    loop {
        let grow_left = i > 0 && count(st[i - 1].start, st[j].end) <= limit;
        if grow_left {
            i -= 1;
        }
        let grow_right = j + 1 < st.len() && count(st[i].start, st[j + 1].end) <= limit;
        if grow_right {
            j += 1;
        }
        if !grow_left && !grow_right {
            break;
        }
    }
    (st[i].start - 100.0, st[j].end + 100.0)
}

pub fn html(an: &Analysis, meta: &Meta, rc: &Receipt) -> String {
    let t0 = an.t0;
    let (w0, w1) = detail_window(an, 600_000);
    let n_ov = 1600usize;
    let q = |t: f64| ((t - t0) * 10.0).round() as i64; // 0.1 us
    let mut d = String::with_capacity(1 << 24);
    d.push_str("{\"cats\":[");
    for (i, (id, c)) in cats().iter().enumerate() {
        if i > 0 {
            d.push(',');
        }
        let _ = write!(d, "[{},{},{}]", id, js_str(c.name), js_str(c.color));
    }
    d.push_str("],\"rows\":[");
    for (i, r) in an.rows.iter().enumerate() {
        if i > 0 {
            d.push(',');
        }
        let _ = write!(d, "{{\"name\":{},\"s\":[", js_str(&r.name));
        let a = r.segs.partition_point(|x| x.0 < w0 - 6.0e6);
        let b = r.segs.partition_point(|x| x.0 <= w1);
        let segs: Vec<&(f64, f64, u8)> = r.segs[a..b].iter().filter(|x| x.0 + x.1 >= w0).collect();
        for (j, s) in segs.iter().enumerate() {
            if j > 0 {
                d.push(',');
            }
            let _ = write!(d, "{}", q(s.0));
        }
        d.push_str("],\"d\":[");
        for (j, s) in segs.iter().enumerate() {
            if j > 0 {
                d.push(',');
            }
            let _ = write!(d, "{}", ((s.1) * 10.0).round() as i64);
        }
        d.push_str("],\"c\":[");
        for (j, s) in segs.iter().enumerate() {
            if j > 0 {
                d.push(',');
            }
            let _ = write!(d, "{}", s.2);
        }
        d.push_str("]}");
    }
    let links: Vec<&Link> = an.links.iter().filter(|l| l.t0 >= w0 && l.t0 <= w1).collect();
    d.push_str("],\"links\":{\"s\":[");
    for (j, l) in links.iter().enumerate() {
        if j > 0 {
            d.push(',');
        }
        let _ = write!(d, "{}", q(l.t0));
    }
    d.push_str("],\"e\":[");
    for (j, l) in links.iter().enumerate() {
        if j > 0 {
            d.push(',');
        }
        let _ = write!(d, "{}", q(l.t1));
    }
    d.push_str("],\"ab\":[");
    for (j, l) in links.iter().enumerate() {
        if j > 0 {
            d.push(',');
        }
        d.push(if l.a_to_b { '1' } else { '0' });
    }
    d.push_str("],\"b\":[");
    for (j, l) in links.iter().enumerate() {
        if j > 0 {
            d.push(',');
        }
        let _ = write!(d, "{}", l.bytes);
    }
    d.push_str("]},\"steps\":[");
    for (j, s) in an.steps.iter().enumerate() {
        if j > 0 {
            d.push(',');
        }
        let _ = write!(d, "[{},{},{},{}]", q(s.start), q(s.end), s.tokens, if s.prefill { 1 } else { 0 });
    }
    d.push_str("],\"metrics\":[");
    for (j, (name, ms)) in an.metrics.iter().enumerate() {
        if j > 0 {
            d.push(',');
        }
        let _ = write!(d, "{{\"name\":{},\"t\":[", js_str(name));
        let ms: Vec<_> = ms.iter().filter(|m| (m.t_us as f64) >= t0 - 1e6 && (m.t_us as f64) <= an.t1 + 1e6).collect();
        for (k, m) in ms.iter().enumerate() {
            if k > 0 {
                d.push(',');
            }
            let _ = write!(d, "{}", q(m.t_us as f64));
        }
        d.push_str("],\"gfx\":[");
        for (k, m) in ms.iter().enumerate() {
            if k > 0 {
                d.push(',');
            }
            let _ = write!(d, "{}", m.gfx_mhz);
        }
        d.push_str("],\"sw\":[");
        for (k, m) in ms.iter().enumerate() {
            if k > 0 {
                d.push(',');
            }
            let _ = write!(d, "{:.1}", m.socket_w);
        }
        d.push_str("],\"cw\":[");
        for (k, m) in ms.iter().enumerate() {
            if k > 0 {
                d.push(',');
            }
            let _ = write!(d, "{:.1}", m.core_w);
        }
        d.push_str("]}");
    }
    // overview: per GPU row, time of each category in n_ov bins over the whole run (us)
    d.push_str("],\"ov\":[");
    let span = an.t1 - an.t0;
    let mut first = true;
    for r in an.rows.iter().filter(|r| r.name.ends_with("GPU")) {
        let mut bins = vec![[0f64; 8]; n_ov];
        for x in r.segs.iter() {
            let c = (x.2 as usize).min(7);
            let (mut a, e) = (x.0, x.0 + x.1);
            while a < e {
                let bi = (((a - an.t0) / span) * n_ov as f64).floor().clamp(0.0, (n_ov - 1) as f64) as usize;
                let be = an.t0 + (bi + 1) as f64 * span / n_ov as f64;
                let b = e.min(be);
                bins[bi][c] += b - a;
                if b <= a {
                    break;
                }
                a = b;
            }
        }
        if !first {
            d.push(',');
        }
        first = false;
        let _ = write!(d, "{{\"name\":{},\"v\":[", js_str(&r.name));
        for (k, b) in bins.iter().enumerate() {
            if k > 0 {
                d.push(',');
            }
            let _ = write!(d, "[{}]", b.iter().map(|v| format!("{:.0}", v)).collect::<Vec<_>>().join(","));
        }
        d.push_str("]}");
    }
    let _ = write!(d, "],\"nov\":{},\"win\":[{},{}],\"span\":{},\"title\":{},\"summary\":{}}}", n_ov, q(w0.max(an.t0)), q(w1.min(an.t1)),
        q(an.t1), js_str(&meta.title), js_str(&rc.summary));

    TEMPLATE
        .replace("__TITLE__", &esc(&meta.title))
        .replace("__META__", &esc(&format!("{} · {} · {}", meta.started, meta.source, rc.summary)))
        .replace("__RECEIPT__", &rc.html)
        .replace("__DATA__", &d)
}

/// The page as a standalone document (opened from disk); `html()` is the body for the artifact viewer, which adds its own.
pub fn full_document(page: &str) -> String {
    format!("<!doctype html>\n<html lang=\"ko\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\"></head><body>\n{}\n</body></html>\n", page)
}

const TEMPLATE: &str = r##"<title>2노드 추론 기록</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* layout: one column — header, the A/B timeline panel (client, A, transfer band, B), then the receipt tables */
:root{--bg:#f6f7f9;--fg:#16181d;--mut:#5d6470;--line:#dde1e8;--panel:#ffffff;--accent:#2f6fb0;--tipbg:#16181d;--tipfg:#f6f7f9;
  --sans:"IBM Plex Sans KR",-apple-system,"Segoe UI","Noto Sans KR",sans-serif;--mono:"IBM Plex Mono",ui-monospace,"SFMono-Regular",Menlo,monospace}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#121418;--fg:#e5e8ed;--mut:#98a0ac;--line:#2a2e36;--panel:#191c22;--accent:#7fb2e5;--tipbg:#e5e8ed;--tipfg:#121418;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#121418;--fg:#e5e8ed;--mut:#98a0ac;--line:#2a2e36;--panel:#191c22;--accent:#7fb2e5;--tipbg:#e5e8ed;--tipfg:#121418;color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:13px/1.5 var(--sans)}
header,.wrap{padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
header{padding-block:14px 4px}
h1{font-size:18px;margin:0 0 2px;font-weight:600;text-wrap:balance}
h3{font-size:14px;margin:20px 0 6px;font-weight:600}
.meta{color:var(--mut);font-family:var(--mono);font-size:12px}
.wrap{padding-block:0 28px}
.panel{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:10px 12px;margin:10px 0;min-width:0}
table{border-collapse:collapse;margin:4px 0 8px;font-variant-numeric:tabular-nums}
th,td{border-bottom:1px solid var(--line);padding:3px 10px;text-align:left;white-space:nowrap}
td.n{text-align:right;font-family:var(--mono);font-size:12px}
th{color:var(--mut);font-weight:600}
.note{color:var(--mut);font-size:12px}
.ctl{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:4px 0 6px}
button{font:inherit;padding:3px 10px;border:1px solid var(--line);background:var(--panel);color:var(--fg);border-radius:6px;cursor:pointer}
button:hover{border-color:var(--accent)}
button:focus-visible{outline:2px solid var(--accent);outline-offset:1px}
#range{color:var(--mut);margin-left:6px;font-family:var(--mono);font-size:12px}
#tl{position:relative;min-width:0}
canvas{display:block;width:100%}
#tip{position:fixed;pointer-events:none;background:var(--tipbg);color:var(--tipfg);padding:5px 8px;border-radius:5px;font-size:12px;display:none;max-width:420px;z-index:5}
.legend{display:flex;flex-wrap:wrap;gap:4px 14px;margin-top:6px}
.legend span{display:inline-flex;align-items:center;gap:5px;color:var(--mut);font-size:12px}
.legend i{width:11px;height:11px;border-radius:2px;display:inline-block}
.tables{overflow-x:auto}
</style>
<header><h1>__TITLE__</h1><div class=meta>__META__</div></header>
<div class=wrap>
<div class=panel>
<div class=ctl><button id=bAll>전체</button><button id=bTok>단계 1개</button><button id=bPrev>◀ 단계</button><button id=bNext>단계 ▶</button><button id=bIn>확대</button><button id=bOut>축소</button><span id=range></span></div>
<div id=tl><canvas id=ov height=46></canvas><canvas id=cv></canvas><canvas id=mt height=110></canvas></div>
<div class=note>휠 = 확대/축소, 끌기 = 이동, 위 띠(전체 개요, 밝은 칠 = 상세 기록이 든 구간) 누르기 = 그곳으로. A·B 보내기·받기 줄 사이의 선 = 부분합 전송(보낸 쪽 post 끝 → 받는 쪽 도착), 빨간 선 = 1 ms 넘게 걸림. 아래 그래프 = GPU 클럭(MHz, 실선)·소켓 W(점선).</div>
<div class=legend id=legend></div>
</div>
<div class="panel tables">__RECEIPT__</div>
</div>
<div id=tip></div>
<script>
const D=__DATA__;
let FG='#16181d', MUT='#5d6470', LINE='#dde1e8';
function readTheme(){ const css=getComputedStyle(document.documentElement); FG=css.getPropertyValue('--fg').trim()||FG; MUT=css.getPropertyValue('--mut').trim()||MUT; LINE=css.getPropertyValue('--line').trim()||LINE; }
const LBL=230, RH=20, GH=28, BAND=46, TOP=34;
const color={}, cname={};
D.cats.forEach(([i,n,c])=>{color[i]=c;cname[i]=n});
const used=new Set(); D.rows.forEach(r=>r.c.forEach(c=>used.add(c)));
const lg=document.getElementById('legend');
D.cats.forEach(([i,n,c])=>{ if(used.has(i)){const s=document.createElement('span');s.innerHTML=`<i style="background:${c}"></i>${n}`;lg.appendChild(s)}});
// row layout: GPU rows taller, a band for the transfer lines between the two net rows
const rows=D.rows.map(r=>({...r,h:r.name.endsWith('GPU')?GH:RH,maxd:r.d.reduce((a,b)=>Math.max(a,b),0)}));
let y=TOP; let bandY=-1;
rows.forEach((r,i)=>{ r.y=y; y+=r.h+3; if(r.name==='A 보내기·받기'){ bandY=y; y+=BAND; } });
const H=y+4;
const cv=document.getElementById('cv'), ov=document.getElementById('ov'), mt=document.getElementById('mt');
const tip=document.getElementById('tip');
let W=0, v0=D.win[0], v1=D.win[1];
const full=(D.win[0]<=0 && D.win[1]>=D.span);
const steps=D.steps.filter(s=>!s[3]);
function setup(){ const dpr=window.devicePixelRatio||1; W=cv.clientWidth;
  for(const [c,h] of [[cv,H],[ov,46],[mt,110]]){ c.width=W*dpr; c.height=h*dpr; c.style.height=h+'px'; c.getContext('2d').setTransform(dpr,0,0,dpr,0,0); } draw(); }
function lo(arr,x){let a=0,b=arr.length;while(a<b){const m=(a+b)>>1;if(arr[m]<x)a=m+1;else b=m;}return a;}
function fmtT(t){const us=t/10; if(Math.abs(us)>=1e6)return (us/1e6).toFixed(3)+' s'; if(Math.abs(us)>=1e3)return (us/1e3).toFixed(2)+' ms'; return us.toFixed(1)+' us';}
function drawRow(g,r,k){
  const x0w=LBL, w=W-LBL; const i0=lo(r.s,v0-r.maxd);
  const buckets=new Map();
  for(let i=i0;i<r.s.length;i++){ const s=r.s[i]; if(s>v1)break; const e=s+r.d[i]; if(e<v0)continue;
    const a=x0w+(Math.max(s,v0)-v0)*k, b=x0w+(Math.min(e,v1)-v0)*k;
    if(b-a>=1){ g.fillStyle=color[r.c[i]]; g.fillRect(a,r.y,b-a,r.h); }
    else { const px=Math.floor(a); let m=buckets.get(px); if(!m){m={};buckets.set(px,m);} m[r.c[i]]=(m[r.c[i]]||0)+(r.d[i]); }
  }
  for(const [px,m] of buckets){ let tot=0; for(const c in m)tot+=m[c]; let yy=r.y; const scale=Math.min(1,tot/(1/k));
    for(const c in m){ const hh=r.h*m[c]/tot; g.fillStyle=color[c]; g.globalAlpha=0.35+0.65*scale; g.fillRect(px,yy,1,hh); yy+=hh; } g.globalAlpha=1; }
}
function draw(){
  readTheme();
  const g=cv.getContext('2d'); g.clearRect(0,0,W,H);
  const k=(W-LBL)/(v1-v0);
  // axis
  g.fillStyle=MUT; g.font='11px sans-serif'; g.strokeStyle=LINE; g.lineWidth=1;
  const span=(v1-v0)/10; const p=Math.pow(10,Math.floor(Math.log10(span/6))); let step=p; for(const m of [1,2,5,10]){ if(span/(p*m)<=10){step=p*m;break;} }
  for(let t=Math.ceil(v0/(step*10))*step*10;t<=v1;t+=step*10){ const x=LBL+(t-v0)*k; g.beginPath(); g.moveTo(x,TOP-6); g.lineTo(x,H); g.stroke(); g.fillText(fmtT(t),x+2,12); }
  // steps band
  steps.forEach((s,i)=>{ if(s[1]<v0||s[0]>v1)return; const a=LBL+(Math.max(s[0],v0)-v0)*k, b=LBL+(Math.min(s[1],v1)-v0)*k;
    g.fillStyle=i%2?'rgba(127,127,127,.10)':'rgba(127,127,127,.20)'; g.fillRect(a,16,b-a,12);
    if(b-a>60){ g.fillStyle=FG; g.fillText(`#${i+1} ${((s[1]-s[0])/1e4).toFixed(2)} ms`,a+3,26); }
    g.strokeStyle='rgba(127,127,127,.35)'; g.beginPath(); g.moveTo(a,16); g.lineTo(a,H); g.stroke(); });
  rows.forEach(r=>{ g.fillStyle=FG; g.font=(r.name.endsWith('GPU')?'bold ':'')+'12px sans-serif'; g.fillText(r.name,6,r.y+r.h/2+4); drawRow(g,r,k); });
  // transfer lines
  if(bandY>0){ const L=D.links; const i0=lo(L.s,v0-2e5); let n=0; for(let i=i0;i<L.s.length&&L.s[i]<=v1;i++)n++;
    const aRow=rows.find(r=>r.name==='A 보내기·받기'), bRow=rows.find(r=>r.name==='B 보내기·받기');
    const ya=aRow.y+aRow.h, yb=bRow.y;
    g.fillStyle=MUT; g.font='11px sans-serif'; g.fillText('전송 A↓ B↑',6,(ya+yb)/2+4);
    if(n<6000){ for(let i=i0;i<L.s.length&&L.s[i]<=v1;i++){ const s=L.s[i], e=L.e[i]; if(e<v0)continue; const late=(e-s)>1e4;
        const xs=LBL+(s-v0)*k, xe=LBL+(e-v0)*k; g.strokeStyle=late?'#e15759':(L.ab[i]?'rgba(78,121,167,.75)':'rgba(242,142,43,.75)'); g.lineWidth=late?2:1;
        g.beginPath(); if(L.ab[i]){g.moveTo(xs,ya);g.lineTo(xe,yb);} else {g.moveTo(xs,yb);g.lineTo(xe,ya);} g.stroke(); } g.lineWidth=1; }
    else { g.fillStyle=MUT; g.fillText(`전송 ${n}개 — 확대하면 선으로 보임`,LBL+6,(ya+yb)/2+4); } }
  drawOv(); drawMt();
  document.getElementById('range').textContent=`${fmtT(v0)} – ${fmtT(v1)} (폭 ${fmtT(v1-v0)})`;
}
let ovCache=null;
function drawOv(){ const g=ov.getContext('2d'); g.clearRect(0,0,W,46);
  if(!ovCache){ ovCache=document.createElement('canvas'); const dpr=window.devicePixelRatio||1; ovCache.width=W*dpr; ovCache.height=46*dpr; const c=ovCache.getContext('2d'); c.setTransform(dpr,0,0,dpr,0,0);
    const bw=(W-LBL)/D.nov; let yy=4;
    for(const o of D.ov){ for(let b=0;b<D.nov;b++){ const v=o.v[b]; let tot=0; for(const x of v)tot+=x; if(!tot)continue; let y2=yy;
        for(let ci=0;ci<v.length;ci++){ if(!v[ci])continue; const hh=17*v[ci]/tot; c.fillStyle=color[ci]; c.fillRect(LBL+b*bw,y2,Math.max(1,bw),hh); y2+=hh; } }
      c.fillStyle=FG; c.font='11px sans-serif'; c.fillText(o.name+' (전체)',6,yy+12); yy+=20; }
    if(!full){ const k=(W-LBL)/D.span; c.fillStyle='rgba(47,111,176,.12)'; c.fillRect(LBL+D.win[0]*k,0,Math.max(2,(D.win[1]-D.win[0])*k),46); } }
  g.drawImage(ovCache,0,0,W,46); const k=(W-LBL)/D.span; g.strokeStyle='#2f6fb0'; g.lineWidth=2; g.strokeRect(LBL+v0*k,1,Math.max(2,(v1-v0)*k),44); g.lineWidth=1; }
function drawMt(){ const g=mt.getContext('2d'); g.clearRect(0,0,W,110); const k=(W-LBL)/(v1-v0);
  g.fillStyle=MUT; g.font='11px sans-serif'; g.fillText('GPU MHz / 소켓 W',6,14);
  const cols={A:'#4e79a7',B:'#f28e2b'}; let yl=30;
  D.metrics.forEach(m=>{ if(!m.t.length)return; g.fillStyle=cols[m.name]; g.fillText(m.name,6,yl+=14);
    const yG=v=>100-(v/3000)*90, yW=v=>100-(v/90)*90;
    g.strokeStyle=cols[m.name]; g.beginPath(); let st=false; for(let i=0;i<m.t.length;i++){ const x=LBL+(m.t[i]-v0)*k; if(x<LBL-50||x>W+50)continue; const yy=yG(m.gfx[i]); if(!st){g.moveTo(x,yy);st=true;} else g.lineTo(x,yy);} g.stroke();
    g.setLineDash([3,3]); g.beginPath(); st=false; for(let i=0;i<m.t.length;i++){ const x=LBL+(m.t[i]-v0)*k; if(x<LBL-50||x>W+50)continue; const yy=yW(m.sw[i]); if(!st){g.moveTo(x,yy);st=true;} else g.lineTo(x,yy);} g.stroke(); g.setLineDash([]); });
  g.fillStyle=MUT; g.fillText('3000',LBL-34,14); g.fillText('0',LBL-12,100); }
function clamp(){ const a=D.win[0], b=D.win[1]; const w=v1-v0; if(w<20){const c=(v0+v1)/2;v0=c-10;v1=c+10;} if(v0<a){v1+=a-v0;v0=a;} if(v1>b){v0-=v1-b;v1=b;} if(v0<a)v0=a; }
function zoom(f,cx){ const t=v0+(cx-LBL)/(W-LBL)*(v1-v0); v0=t-(t-v0)*f; v1=t+(v1-t)*f; clamp(); draw(); }
cv.addEventListener('wheel',e=>{ e.preventDefault(); const r=cv.getBoundingClientRect(); zoom(e.deltaY>0?1.25:0.8,e.clientX-r.left); },{passive:false});
let drag=null; cv.addEventListener('mousedown',e=>{drag={x:e.clientX,v0,v1};});
window.addEventListener('mouseup',()=>drag=null);
window.addEventListener('mousemove',e=>{ if(drag){ const dt=(e.clientX-drag.x)/(W-LBL)*(drag.v1-drag.v0); v0=drag.v0-dt; v1=drag.v1-dt; clamp(); draw(); tip.style.display='none'; return; } hover(e); });
ov.addEventListener('click',e=>{ const r=ov.getBoundingClientRect(); const t=(e.clientX-r.left-LBL)/(W-LBL)*D.span; const w=v1-v0; v0=t-w/2; v1=t+w/2; clamp(); draw(); });
function hover(e){ const r=cv.getBoundingClientRect(); const x=e.clientX-r.left, yy=e.clientY-r.top; if(x<LBL||yy<0||yy>H||e.target!==cv){tip.style.display='none';return;}
  const t=v0+(x-LBL)/(W-LBL)*(v1-v0); const row=rows.find(rr=>yy>=rr.y&&yy<=rr.y+rr.h); let html='';
  if(row){ const i0=lo(row.s,t-row.maxd); let best=-1; for(let i=i0;i<row.s.length&&row.s[i]<=t;i++){ if(row.s[i]+row.d[i]>=t) best=i; }
    if(best<0){ const tol=3/((W-LBL)/(v1-v0)); for(let i=lo(row.s,t-tol-row.maxd);i<row.s.length&&row.s[i]<=t+tol;i++){ if(row.s[i]+row.d[i]>=t-tol){best=i;break;} } }
    if(best>=0) html=`<b>${row.name}</b><br>${cname[row.c[best]]}<br>시작 ${fmtT(row.s[best])} · 길이 <b>${fmtT(row.d[best])}</b>`; }
  else if(bandY>0 && yy>=bandY-3 && yy<=bandY+BAND){ const L=D.links; let best=-1,bd=1e18; for(let i=lo(L.s,t-3e4);i<L.s.length&&L.s[i]<=t+3e4;i++){ const m=(L.s[i]+L.e[i])/2; const dd=Math.abs(m-t); if(dd<bd){bd=dd;best=i;} }
    if(best>=0) html=`<b>전송 ${L.ab[best]?'A → B':'B → A'}</b> ${L.b[best]} B<br>보냄 ${fmtT(L.s[best])} → 도착 ${fmtT(L.e[best])}<br>지연 <b>${fmtT(L.e[best]-L.s[best])}</b>`; }
  const st=steps.findIndex(s=>t>=s[0]&&t<s[1]); if(st>=0) html+=`<br><span style="opacity:.75">decode 단계 #${st+1} (${((steps[st][1]-steps[st][0])/1e4).toFixed(2)} ms)</span>`;
  if(!html){tip.style.display='none';return;} tip.innerHTML=html; tip.style.display='block'; tip.style.left=(e.clientX+14)+'px'; tip.style.top=(e.clientY+12)+'px'; }
let cur=Math.max(0,steps.findIndex(s=>s[0]>=D.win[0]&&s[1]<=D.win[1])); { const inwin=steps.map((s,i)=>[s,i]).filter(([s])=>s[0]>=D.win[0]&&s[1]<=D.win[1]); if(inwin.length) cur=inwin[Math.floor(inwin.length/2)][1]; }
function showStep(i){ if(!steps.length)return; cur=Math.max(0,Math.min(steps.length-1,i)); const s=steps[cur]; if(s[1]<D.win[0]||s[0]>D.win[1]){ document.getElementById('range').textContent='이 단계는 상세 구간 밖 — 위 띠의 밝은 구간만 상세 기록이 들어 있음'; return; } const pad=(s[1]-s[0])*0.04; v0=s[0]-pad; v1=s[1]+pad; clamp(); draw(); }
document.getElementById('bAll').onclick=()=>{v0=D.win[0];v1=D.win[1];draw();};
document.getElementById('bTok').onclick=()=>showStep(cur);
document.getElementById('bPrev').onclick=()=>showStep(cur-1);
document.getElementById('bNext').onclick=()=>showStep(cur+1);
document.getElementById('bIn').onclick=()=>zoom(0.5,LBL+(W-LBL)/2);
document.getElementById('bOut').onclick=()=>zoom(2,LBL+(W-LBL)/2);
window.addEventListener('resize',()=>{ovCache=null;setup();});
try{ matchMedia('(prefers-color-scheme: dark)').addEventListener('change',()=>{ovCache=null;draw();}); }catch(e){}
new MutationObserver(()=>{ovCache=null;draw();}).observe(document.documentElement,{attributes:true,attributeFilter:['data-theme']});
setup(); if(steps.length) showStep(cur);
</script>
"##;

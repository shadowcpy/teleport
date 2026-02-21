use std::{collections::VecDeque, time::Instant};

const ALPHA: f64 = 0.9;
const WINDOW: usize = 100;

pub struct SpeedSample {
    time: Instant,
    bytes: u64,
}

pub struct SpeedTracker {
    points: VecDeque<SpeedSample>,
}

impl SpeedTracker {
    pub fn new() -> Self {
        Self {
            points: VecDeque::with_capacity(WINDOW),
        }
    }

    pub fn update_now(&mut self, bytes: u64) {
        self.update(Instant::now(), bytes);
    }

    pub fn update(&mut self, time: Instant, bytes: u64) {
        if self.points.back().is_some_and(|b| bytes < b.bytes) {
            panic!("Bytes were un-transferred?")
        }
        if self.points.len() == WINDOW {
            self.points.pop_front();
        }
        self.points.push_back(SpeedSample { time, bytes });
    }

    pub fn speed(&self) -> f64 {
        exp_ma(&self.points)
    }
}

fn exp_ma(points: &VecDeque<SpeedSample>) -> f64 {
    if points.len() < 2 {
        return 0.0;
    }

    let mut ema: Option<f64> = None;
    for (a, b) in points.iter().zip(points.iter().skip(1)) {
        let time = b.time.duration_since(a.time).as_secs_f64();
        if time <= 0.0 {
            continue;
        }
        let bytes = b.bytes.saturating_sub(a.bytes);
        let speed = bytes as f64 / time;
        ema = Some(match ema {
            None => speed,
            Some(prev) => (ALPHA * prev) + ((1.0 - ALPHA) * speed),
        });
    }

    ema.unwrap_or(0.0)
}

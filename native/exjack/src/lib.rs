//! Elixir NIF to JACK audio server API.

mod atoms;
use rustler::{Atom, Encoder, Env, Error, NifMap, OwnedEnv, ResourceArc, Term};
use std::sync::{mpsc, Mutex};
use std::{thread, time};

type Sample = f32;

pub struct SenderChannel(Mutex<mpsc::Sender<Vec<Sample>>>);
pub struct ShutdownChannel(Mutex<Option<mpsc::Sender<()>>>);
type StartResult = Result<
    (
        Atom,
        ResourceArc<SenderChannel>,
        ResourceArc<ShutdownChannel>,
        Pcm,
    ),
    Error,
>;

#[derive(NifMap)]
pub struct Pcm {
    pub buffer_size: u32,
    pub sample_rate: usize,
}

#[derive(NifMap)]
pub struct Config {
    pub name: String,
    pub auto_connect: bool,
    pub use_callback: bool,
}

pub fn load(env: Env, _: Term) -> bool {
    rustler::resource!(SenderChannel, env);
    rustler::resource!(ShutdownChannel, env);
    true
}

#[rustler::nif]
pub fn _start(env: Env, config: Config) -> StartResult {
    let (client, _status) =
        jack::Client::new(&config.name, jack::ClientOptions::NO_START_SERVER).unwrap();

    let mut out_port = client
        .register_port("out", jack::AudioOut::default())
        .unwrap();

    let pid = env.pid();

    let (shutdown_tx, shutdown_rx) = mpsc::channel::<()>();
    let (frames_tx, frames_rx) = mpsc::channel::<Vec<Sample>>();

    let use_callback = config.use_callback;
    let process = jack::ClosureProcessHandler::new(
        move |_: &jack::Client, ps: &jack::ProcessScope| -> jack::Control {
            if use_callback {
                let mut env = OwnedEnv::new();
                env.send_and_clear(&pid, move |env| {
                    let frames = ps.n_frames();
                    (atoms::request(), frames).encode(env)
                });
            }

            let out = out_port.as_mut_slice(ps);

            while let Ok(f) = frames_rx.try_recv() {
                out.clone_from_slice(&f);
            }

            jack::Control::Continue
        },
    );

    let buffer_size = client.buffer_size();
    let sample_rate = client.sample_rate();

    std::thread::spawn(move || {
        let active_client = client.activate_async((), process).unwrap();

        if config.auto_connect {
            active_client
                .as_client()
                .connect_ports_by_name(&format!("{}:out", config.name), "system:playback_1")
                .unwrap();
            active_client
                .as_client()
                .connect_ports_by_name(&format!("{}:out", config.name), "system:playback_2")
                .unwrap();
        }

        let ten_seconds = time::Duration::from_secs(10);
        while let Err(_) = shutdown_rx.try_recv() {
            thread::sleep(ten_seconds);
        }
    });

    let shutdown_ref = ResourceArc::new(ShutdownChannel(Mutex::new(Some(shutdown_tx))));
    let sender_ref = ResourceArc::new(SenderChannel(Mutex::new(frames_tx)));

    Ok((
        atoms::ok(),
        sender_ref,
        shutdown_ref,
        Pcm {
            buffer_size,
            sample_rate,
        },
    ))
}

#[rustler::nif]
fn send_frames(resource: ResourceArc<SenderChannel>, frames: Vec<Sample>) -> Atom {
    let arc = resource.0.lock().unwrap().clone();
    let _ = arc.send(frames);
    atoms::ok()
}

#[rustler::nif]
pub fn stop(resource: ResourceArc<ShutdownChannel>) -> Atom {
    let mut lock = resource.0.lock().unwrap();

    if let Some(tx) = lock.take() {
        let _ = tx.send(());
    }

    atoms::ok()
}

rustler::init!(
    "Elixir.ExJack.Native",
    [_start, stop, send_frames],
    load = load
);

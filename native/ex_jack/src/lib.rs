//! Elixir NIF to JACK audio server API.

mod atoms;
use rustler::{Atom, Encoder, Env, Error, LocalPid, NifMap, OwnedEnv, ResourceArc, Term};
use std::sync::{mpsc, Mutex};
use std::{thread, time};

type Sample = f32;

pub struct SendFramesChannel(Mutex<mpsc::Sender<Vec<Sample>>>);
pub struct ShutdownChannel(Mutex<Option<mpsc::Sender<()>>>);

type StartResult = Result<
    (
        Atom,
        ResourceArc<SendFramesChannel>,
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
    rustler::resource!(SendFramesChannel, env);
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

    let in_port = client
        .register_port("in", jack::AudioIn::default())
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

            let in_frames = in_port.as_slice(ps);

            if in_frames.len() > 0 {
                let mut env = OwnedEnv::new();
                env.send_and_clear(&pid, move |env| (atoms::in_frames(), in_frames).encode(env));
            }

            let out_frames = out_port.as_mut_slice(ps);

            while let Ok(f) = frames_rx.try_recv() {
                out_frames.clone_from_slice(&f);
            }

            jack::Control::Continue
        },
    );

    let buffer_size = client.buffer_size();
    let sample_rate = client.sample_rate();

    std::thread::spawn(move || {
        let active_client = client
            .activate_async(Notifications::create(pid), process)
            .unwrap();

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
    let sender_ref = ResourceArc::new(SendFramesChannel(Mutex::new(frames_tx)));

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

struct Notifications {
    env_pid: LocalPid,
}

impl Notifications {
    fn create(env_pid: LocalPid) -> Notifications {
        Notifications { env_pid }
    }
}

impl jack::NotificationHandler for Notifications {
    fn shutdown(&mut self, _status: jack::ClientStatus, _reason: &str) {
        let mut env = OwnedEnv::new();
        env.send_and_clear(&self.env_pid, move |env| atoms::shutdown().encode(env));
    }

    fn sample_rate(&mut self, _: &jack::Client, srate: jack::Frames) -> jack::Control {
        let mut env = OwnedEnv::new();
        env.send_and_clear(&self.env_pid, move |env| {
            (atoms::sample_rate(), srate).encode(env)
        });

        jack::Control::Continue
    }

    fn client_registration(&mut self, _: &jack::Client, name: &str, is_reg: bool) {
        let mut env = OwnedEnv::new();
        if is_reg {
            env.send_and_clear(&self.env_pid, move |env| {
                (atoms::client_register(), name).encode(env)
            });
        } else {
            env.send_and_clear(&self.env_pid, move |env| {
                (atoms::client_unregister(), name).encode(env)
            });
        }
    }

    fn port_registration(&mut self, client: &jack::Client, port_id: jack::PortId, is_reg: bool) {
        if let Some(port) = client.port_by_id(port_id) {
            let mut env = OwnedEnv::new();
            if is_reg {
                env.send_and_clear(&self.env_pid, move |env| {
                    (atoms::port_register(), port_id, port.name().unwrap_or("<unknown>".to_owned())).encode(env)
                });
            } else {
                env.send_and_clear(&self.env_pid, move |env| {
                    (atoms::port_unregister(), port_id).encode(env)
                });
            }
        }
    }

    fn ports_connected(
        &mut self,
        _: &jack::Client,
        port_id_a: jack::PortId,
        port_id_b: jack::PortId,
        are_connected: bool,
    ) {
        let mut env = OwnedEnv::new();
        if are_connected {
            env.send_and_clear(&self.env_pid, move |env| {
                (atoms::ports_connected(), port_id_a, port_id_b).encode(env)
            });
        } else {
            env.send_and_clear(&self.env_pid, move |env| {
                (atoms::ports_disconnected(), port_id_a, port_id_b).encode(env)
            });
        }
    }

    fn xrun(&mut self, _: &jack::Client) -> jack::Control {
        let mut env = OwnedEnv::new();
        env.send_and_clear(&self.env_pid, move |env| atoms::xrun().encode(env));

        jack::Control::Continue
    }
}

#[rustler::nif]
fn send_frames(resource: ResourceArc<SendFramesChannel>, frames: Vec<Sample>) -> Atom {
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

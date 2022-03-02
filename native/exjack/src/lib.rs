//! Elixir NIF to JACK audio server API.

mod atoms;
use rustler::{Atom, Encoder, Env, Error, OwnedEnv, ResourceArc, Term};
use futures::channel::oneshot;
use std::sync::atomic::AtomicBool;
use std::sync::{mpsc, Arc, Mutex};

pub struct SenderChannel(Mutex<mpsc::Sender<Vec<f32>>>);
pub struct ResponseChannel(Mutex<Option<oneshot::Sender<String>>>);
pub struct ShutdownChannel(Mutex<Option<oneshot::Sender<()>>>);
pub struct Select(Arc<AtomicBool>);
type BufferSize = u32;
type StartResult = Result<(Atom, ResourceArc<SenderChannel>, BufferSize), Error>;

pub fn load(env: Env, _: Term) -> bool {
    rustler::resource!(ResponseChannel, env);
    rustler::resource!(Select, env);
    rustler::resource!(ShutdownChannel, env);
    rustler::resource!(SenderChannel, env);
    true
}

#[rustler::nif]
pub fn start(env: Env, _term: Term) -> StartResult {
    let (client, _status) =
        jack::Client::new("rust_jack_sine", jack::ClientOptions::NO_START_SERVER).unwrap();

    let mut out_port = client
        .register_port("sine_out", jack::AudioOut::default())
        .unwrap();

    let pid = env.pid();


    let (tx, rx) = mpsc::channel::<Vec<f32>>();
    let process = jack::ClosureProcessHandler::new(
        move |_: &jack::Client, ps: &jack::ProcessScope| -> jack::Control {
            let mut env = OwnedEnv::new();
            env.send_and_clear(&pid, move |env| {
                let frames = ps.n_frames();
                (atoms::request(), frames).encode(env)
            });

            let out = out_port.as_mut_slice(ps);
            
            while let Ok(f) = rx.try_recv() {
                println!("Received");
                out.clone_from_slice(&f);
            }

            jack::Control::Continue
        },
    );


    let buffer_size = client.buffer_size();
    let sample_rate = client.sample_rate();

    std::thread::spawn(move || {
        let active_client = client.activate_async((), process).unwrap();

        active_client
            .as_client()
            .connect_ports_by_name("rust_jack_sine:sine_out", "system:playback_1")
            .unwrap();
        active_client
            .as_client()
            .connect_ports_by_name("rust_jack_sine:sine_out", "system:playback_2")
            .unwrap();

        loop {}
    });
    // 6. Optional deactivate. Not required since active_client will deactivate on
    // drop, though explicit deactivate may help you identify errors in
    // deactivate.
    //active_client.deactivate().unwrap();

    /*
    let (shutdown_tx, shutdown_rx) = futures::sync::oneshot::channel::<()>();
    let select = Arc::new(AtomicBool::new(false));
    let select_ref = ResourceArc::new(Select(Arc::clone(&select)));
    let shutdown_ref = ResourceArc::new(ShutdownChannel(Mutex::new(Some(shutdown_tx))));

    std::thread::spawn(move || {
        let mut env = OwnedEnv::new();
        /*
        env.send_and_clear(&pid, move |env| {

        });
        */
    });
    */

    let sender_ref = ResourceArc::new(SenderChannel(Mutex::new(tx)));
    Ok((atoms::ok(), sender_ref, buffer_size))
}

#[rustler::nif]
fn send_frames(resource: ResourceArc<SenderChannel>, frames: Vec<f32>) -> Atom {
    let arc = resource.0.lock().unwrap().clone();
    let _ = arc.send(frames);
    atoms::ok()
}

rustler::init!(
    "Elixir.ExJack.Native",
    [
        start,
        //stop,
        send_frames
    ],
    load = load
);

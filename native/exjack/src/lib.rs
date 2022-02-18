//! Sine wave generator with frequency configuration exposed through standard
//! input.

mod atoms;
//use crate::atoms;
use rustler::{Atom, Encoder, Env, Error, NifMap as Map, OwnedEnv, ResourceArc, Term};
//use crossbeam::channel::bounded;
use futures::channel::oneshot;
//use std::str::FromStr;
use futures::*;
use std::sync::atomic::{AtomicBool};
use std::sync::{Arc, Mutex, mpsc};

pub struct SenderChannel(Mutex<mpsc::Sender<Vec<f64>>>);
pub struct ResponseChannel(Mutex<Option<oneshot::Sender<String>>>);
pub struct ShutdownChannel(Mutex<Option<oneshot::Sender<()>>>);
pub struct Select(Arc<AtomicBool>);
type StartResult = Result<(Atom, ResourceArc<SenderChannel>), Error>;

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

    let (tx, rx) = mpsc::channel::<Vec<f64>>();
    let process = jack::ClosureProcessHandler::new(
        move |_: &jack::Client, ps: &jack::ProcessScope| -> jack::Control {
            // Get output buffer
            let out = out_port.as_mut_slice(ps);
            println!("{:?}", out.len());
            let frames = vec![];

            while let Ok(f) = rx.try_recv() {
                frames = f;
                println!("Received!!!!!!");
            }

            // Write output
            for v in out.iter_mut() {
                *v = y as f32;
            }

            // Continue as normal
            jack::Control::Continue
        },
    );

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

        loop {
        }
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
    Ok((atoms::ok(), sender_ref))
}


#[rustler::nif]
fn send_frames(resource: ResourceArc<SenderChannel>, frames: Vec<f64>) -> Atom {
    let arc = resource.0.lock().unwrap().clone();
    let _ = arc.send(frames);
    atoms::ok()
}

rustler::init!("Elixir.ExJack.Native", [
    start,
    //stop,
    send_frames
],
load = load
);



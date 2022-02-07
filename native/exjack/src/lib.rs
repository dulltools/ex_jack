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

//pub struct SenderChannel(Mutex<Option<oneshot::Sender<i32>>>);
pub struct SenderChannel(Mutex<Option<mpsc::Sender<i32>>>);
pub struct ResponseChannel(Mutex<Option<oneshot::Sender<String>>>);
pub struct ShutdownChannel(Mutex<Option<oneshot::Sender<()>>>);
pub struct Select(Arc<AtomicBool>);
//type StartResult = Result<(Atom, ResourceArc<ShutdownChannel>, ResourceArc<Select>), Error>;
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

    let mut frequency = 220;
    let sample_rate = client.sample_rate();
    let frame_t = 1.0 / sample_rate as f64;
    let mut time = 0.0;
    //let (tx, mut rx) = oneshot::channel::<i32>();
    let (tx, rx) = mpsc::channel::<i32>();
    let process = jack::ClosureProcessHandler::new(
        move |_: &jack::Client, ps: &jack::ProcessScope| -> jack::Control {
            // Get output buffer
            let out = out_port.as_mut_slice(ps);

            // Check frequency requests
            /*
            futures::executor::block_on(async {
                println!("MAIN: waiting for msg...");
                println!("MAIN: got: {:?}", rx.await)
            });
            */
            while let Ok(f) = rx.try_recv() {
                time = 0.0;
                frequency = f;
                println!("Received!!!!!!");
            }

            // Write output
            for v in out.iter_mut() {
                let x = frequency as f64 * time * 2.0 * std::f64::consts::PI;
                let y = x.sin();
                *v = y as f32;
                time += frame_t;
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
    // processing starts here

    // 5. wait or do some processing while your handler is running in real time.
    println!("Enter an integer value to change the frequency of the sine wave.");
        //tx.send(f).unwrap();

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

    let sender_ref = ResourceArc::new(SenderChannel(Mutex::new(Some(tx))));
    Ok((atoms::ok(), sender_ref))
}


#[rustler::nif]
fn send_frames(resource: ResourceArc<SenderChannel>, frames: i32) -> Atom {
    let mut lock = resource.0.lock().unwrap();
    println!("Sending frames {}", frames);

    if let Some(tx) = lock.take() {
        let _ = tx.send(frames);
        drop(lock);
        atoms::ok()
    } else {
        println!("Could not get lock!!!!!!!!");
        atoms::error()
    }
}

rustler::init!("Elixir.ExJack.Native", [
    start,
    //stop,
    send_frames
],
load = load
);



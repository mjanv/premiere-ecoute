//! Minimal fxc replacement: `hlslc <file.hlsl> <entry> <target> <out.rs-const-name>`
//! Prints `const NAME: &[u8] = &[..];` using the OS's d3dcompiler_47.dll.
use windows::Win32::Graphics::Direct3D::Fxc::{D3DCOMPILE_OPTIMIZATION_LEVEL3, D3DCompile};
use windows::core::{PCSTR, s};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (file, entry, target, name) = (&args[1], &args[2], &args[3], &args[4]);
    let src = std::fs::read(file).expect("read hlsl");
    let entry = format!("{entry}\0");
    let target = format!("{target}\0");
    let mut code = None;
    let mut errors = None;
    let result = unsafe {
        D3DCompile(
            src.as_ptr().cast(),
            src.len(),
            s!("shader.hlsl"),
            None,
            None,
            PCSTR(entry.as_ptr()),
            PCSTR(target.as_ptr()),
            D3DCOMPILE_OPTIMIZATION_LEVEL3,
            0,
            &mut code,
            Some(&mut errors),
        )
    };
    if let Err(e) = result {
        let msg = errors
            .map(|b| unsafe {
                String::from_utf8_lossy(std::slice::from_raw_parts(
                    b.GetBufferPointer().cast::<u8>(),
                    b.GetBufferSize(),
                ))
                .into_owned()
            })
            .unwrap_or_default();
        eprintln!("{e}\n{msg}");
        std::process::exit(1);
    }
    let blob = code.unwrap();
    let bytes = unsafe {
        std::slice::from_raw_parts(blob.GetBufferPointer().cast::<u8>(), blob.GetBufferSize())
    };
    let list: Vec<String> = bytes.iter().map(|b| format!("0x{b:02x}")).collect();
    println!("const {name}: &[u8] = &[{}];", list.join(", "));
}

// Patched for cross-compilation: the upstream script only compiles shaders when the *host* is
// Windows. Here, shaders are pre-compiled by tools/gen-shaders.sh into shaders_bytes.rs.
fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=shaders_bytes.rs");
    let out_dir = std::env::var("OUT_DIR").unwrap();
    let manifest = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    std::fs::copy(
        format!("{manifest}/shaders_bytes.rs"),
        format!("{out_dir}/shaders_bytes.rs"),
    )
    .expect("missing shaders_bytes.rs; run tools/gen-shaders.sh");
}

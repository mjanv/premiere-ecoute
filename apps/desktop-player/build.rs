// Embeds the icon and version info into the Windows exe (llvm-rc when cross-compiling from WSL).
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        println!("cargo:rerun-if-changed=assets/app.rc");
        println!("cargo:rerun-if-changed=assets/icon.ico");
        embed_resource::compile("assets/app.rc", embed_resource::NONE)
            .manifest_required()
            .unwrap();
    }
}

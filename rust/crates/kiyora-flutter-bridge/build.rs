use std::{env, fs, io::Write, path::PathBuf};

fn main() {
    for name in ["KIYORA_TELEGRAM_CONFIG", "XDG_CONFIG_HOME", "HOME"] {
        println!("cargo:rerun-if-env-changed={name}");
    }
    let explicit = env::var_os("KIYORA_TELEGRAM_CONFIG");
    let path = explicit.clone().map(PathBuf::from).or_else(|| {
        env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))
            .map(|root| root.join("kiyora-build/telegram.json"))
    });
    let mut packed = Vec::new();
    if let Some(path) = path.as_ref() {
        println!("cargo:rerun-if-changed={}", path.display());
        if path.exists() {
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let metadata =
                    fs::metadata(path).expect("Cannot read Telegram build configuration metadata");
                assert_eq!(
                    metadata.permissions().mode() & 0o077,
                    0,
                    "Telegram build configuration must be private (chmod 600)"
                );
            }
            // Never attach parser errors, file contents or values to diagnostics.
            let bytes = fs::read(path).expect("Cannot read Telegram build configuration");
            let config: serde_json::Value = serde_json::from_slice(&bytes)
                .unwrap_or_else(|_| panic!("Invalid Telegram build configuration JSON"));
            let id = config["api_id"]
                .as_i64()
                .and_then(|v| i32::try_from(v).ok())
                .filter(|v| *v > 0)
                .expect("Invalid Telegram application ID in build configuration");
            let hash = config["api_hash"]
                .as_str()
                .filter(|v| v.len() == 32 && v.bytes().all(|b| b.is_ascii_hexdigit()))
                .expect("Invalid Telegram application hash in build configuration");
            packed.extend_from_slice(&id.to_le_bytes());
            packed.extend_from_slice(hash.as_bytes());
        }
    }
    assert!(
        !packed.is_empty()
            || (explicit.is_none() && env::var("PROFILE").as_deref() != Ok("release")),
        "Telegram build configuration is missing; set KIYORA_TELEGRAM_CONFIG to a private JSON file"
    );
    let output =
        PathBuf::from(env::var_os("OUT_DIR").expect("Cargo OUT_DIR missing")).join("telegram.bin");
    let mut options = fs::OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut file = options
        .open(output)
        .expect("Cannot create native Telegram build configuration");
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        file.set_permissions(fs::Permissions::from_mode(0o600))
            .expect("Cannot protect native Telegram build configuration");
    }
    file.write_all(&packed)
        .expect("Cannot write native Telegram build configuration");
}

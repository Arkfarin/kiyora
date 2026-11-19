//! Authentication delegates exclusively to the existing TDLib state machine.
use super::{BridgeError, id, runtime};
use tokio_util::sync::CancellationToken;

// No Debug: these values include ephemeral credentials.
#[derive(Clone)]
pub enum Login {
    Phone(String),
    Code(String),
    Password(String),
    Qr,
    Email(String),
    EmailCode(String),
    ResendCode,
}
#[derive(Clone)]
pub enum Authorization {
    ParametersRequired,
    PhoneRequired,
    CodeRequired {
        delivery: String,
        expected_length: Option<u32>,
        timeout_seconds: Option<u32>,
        next_delivery: Option<String>,
    },
    PasswordRequired,
    QrConfirmation {
        link: String,
    },
    EmailRequired,
    EmailCodeRequired {
        expected_length: Option<u32>,
    },
    RegistrationRequired,
    PremiumRequired,
    Ready,
    LoggingOut,
    Closing,
    Closed,
    Unsupported,
}
impl From<vault_telegram::AuthStatus> for Authorization {
    fn from(s: vault_telegram::AuthStatus) -> Self {
        use vault_telegram::AuthStatus as A;
        match s {
            A::ParametersRequired => Self::ParametersRequired,
            A::PhoneRequired => Self::PhoneRequired,
            A::CodeRequired { code_info: c } => Self::CodeRequired {
                delivery: format!("{:?}", c.delivery),
                expected_length: c.expected_length,
                timeout_seconds: c.timeout_seconds,
                next_delivery: c.next_delivery.map(|v| format!("{v:?}")),
            },
            A::PasswordRequired => Self::PasswordRequired,
            A::QrConfirmation { link } => Self::QrConfirmation { link },
            A::EmailRequired => Self::EmailRequired,
            A::EmailCodeRequired { expected_length } => Self::EmailCodeRequired { expected_length },
            A::RegistrationRequired => Self::RegistrationRequired,
            A::PremiumRequired => Self::PremiumRequired,
            A::Ready => Self::Ready,
            A::LoggingOut => Self::LoggingOut,
            A::Closing => Self::Closing,
            A::Closed => Self::Closed,
            A::Unsupported => Self::Unsupported,
        }
    }
}
/// Explicit cancellation survives widget rebuilds and does not imply rollback
/// of an operation already acknowledged by Telegram.
#[flutter_rust_bridge::frb(opaque)]
pub struct Operation {
    pub(super) token: CancellationToken,
}
impl Operation {
    pub fn new() -> Self {
        Self {
            token: CancellationToken::new(),
        }
    }
    pub fn cancel(&self) {
        self.token.cancel();
    }
}
impl Default for Operation {
    fn default() -> Self {
        Self::new()
    }
}

pub async fn connect(
    session_id: String,
    api_id: i32,
    api_hash: String,
) -> Result<Authorization, BridgeError> {
    let secret = zeroize::Zeroizing::new(api_hash);
    Ok(runtime()
        .await?
        .backend
        .connect_native(id(&session_id)?, api_id, secret)
        .await?
        .into())
}
pub async fn status(session_id: String) -> Result<Authorization, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .auth_status(id(&session_id)?)
        .await?
        .into())
}
pub async fn authenticate(
    session_id: String,
    input: Login,
    operation: &Operation,
) -> Result<Authorization, BridgeError> {
    use vault_core::LoginInput as L;
    let input = match input {
        Login::Phone(v) => L::Phone(v),
        Login::Code(v) => L::Code(v),
        Login::Password(v) => L::Password(v),
        Login::Qr => L::Qr,
        Login::Email(v) => L::Email(v),
        Login::EmailCode(v) => L::EmailCode(v),
        Login::ResendCode => L::ResendCode,
    };
    // Convert to Zeroizing input before awaiting the runtime lock.
    let input = input.into();
    Ok(runtime()
        .await?
        .backend
        .authenticate(id(&session_id)?, input, &operation.token)
        .await?
        .into())
}
pub async fn reconnect(session_id: String) -> Result<Authorization, BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .reconnect(id(&session_id)?)
        .await?
        .into())
}
pub async fn logout(session_id: String) -> Result<(), BridgeError> {
    Ok(runtime().await?.backend.logout(id(&session_id)?).await?)
}
pub async fn disconnect(session_id: String) -> Result<(), BridgeError> {
    Ok(runtime()
        .await?
        .backend
        .disconnect(id(&session_id)?)
        .await?)
}

//! Blocking HTTP for the token endpoint: timeouts everywhere, no redirects, bounded responses.

use super::oauth::{Http, HttpResponse};
use std::time::Duration;

const TOTAL_TIMEOUT: Duration = Duration::from_secs(15);
const MAX_BODY: u64 = 256 * 1024;

pub struct UreqHttp {
    agent: ureq::Agent,
}

impl UreqHttp {
    pub fn new() -> Self {
        let agent = ureq::Agent::config_builder()
            .timeout_global(Some(TOTAL_TIMEOUT))
            .max_redirects(0)
            // 4xx answers carry the OAuth error we need to read.
            .http_status_as_error(false)
            .build()
            .into();
        Self { agent }
    }
}

impl Http for UreqHttp {
    fn post_form(&self, url: &str, form: &[(&str, &str)]) -> Result<HttpResponse, String> {
        let mut response = self
            .agent
            .post(url)
            .send_form(form.iter().copied())
            .map_err(|e| e.to_string())?;
        let status = response.status().as_u16();
        let body = response
            .body_mut()
            .with_config()
            .limit(MAX_BODY)
            .read_to_string()
            .map_err(|e| e.to_string())?;
        Ok(HttpResponse { status, body })
    }
}

#[cfg(test)]
mod tests;

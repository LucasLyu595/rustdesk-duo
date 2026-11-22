use base::config::keys::{
    OPTION_ALLOW_WEBSOCKET, OPTION_API_SERVER, OPTION_CUSTOM_RENDEZVOUS_SERVER, OPTION_KEY,
    OPTION_RELAY_SERVER,
};
use std::collections::HashMap;

// Public on purpose: the DNS name and public key of the own server on the M4, reached over
// WebSocket through its Cloudflare Tunnel.
const SERVER: &str = "rustdesk-ws.lucasagenda.dpdns.org";
const API_SERVER: &str = "https://rustdesk-ws.lucasagenda.dpdns.org";
const KEY: &str = "OT7S8Kovaw7vaBs6vvW2ZmxN6Mklh0NvNF8dOBE5zpk=";

pub(crate) fn fill_defaults(defaults: &mut HashMap<String, String>) {
    for (k, v) in [
        (OPTION_CUSTOM_RENDEZVOUS_SERVER, SERVER),
        (OPTION_RELAY_SERVER, SERVER),
        (OPTION_KEY, KEY),
        (OPTION_ALLOW_WEBSOCKET, "Y"),
        (OPTION_API_SERVER, API_SERVER),
    ] {
        defaults.entry(k.to_owned()).or_insert_with(|| v.to_owned());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fill_defaults_sets_own_server_when_absent() {
        let mut m = HashMap::new();
        fill_defaults(&mut m);
        assert_eq!(m.len(), 5);
        assert_eq!(m["custom-rendezvous-server"], "rustdesk-ws.lucasagenda.dpdns.org");
        assert_eq!(m["relay-server"], "rustdesk-ws.lucasagenda.dpdns.org");
        assert_eq!(m["key"], "OT7S8Kovaw7vaBs6vvW2ZmxN6Mklh0NvNF8dOBE5zpk=");
        assert_eq!(m["allow-websocket"], "Y");
        assert_eq!(m["api-server"], "https://rustdesk-ws.lucasagenda.dpdns.org");
    }

    #[test]
    fn fill_defaults_keeps_existing_entries() {
        let mut m = HashMap::new();
        m.insert("custom-rendezvous-server".to_owned(), "example.com".to_owned());
        fill_defaults(&mut m);
        assert_eq!(m["custom-rendezvous-server"], "example.com");
        assert_eq!(m["relay-server"], "rustdesk-ws.lucasagenda.dpdns.org");
        assert_eq!(m["key"], "OT7S8Kovaw7vaBs6vvW2ZmxN6Mklh0NvNF8dOBE5zpk=");
        assert_eq!(m["allow-websocket"], "Y");
        assert_eq!(m["api-server"], "https://rustdesk-ws.lucasagenda.dpdns.org");
    }
}

# IDE-003: A model door for a room: socat in the room namespace to the host LLM gateway socket (Plan F section 2)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Plan F §2: a unit with `NetworkNamespacePath=` the room's runs
`socat TCP-LISTEN:<net.host>:<port>,fork UNIX-CONNECT:/run/llm-gateway/api.sock`,
`DynamicUser`, `SupplementaryGroups=llm-gateway`; the guest holds a gateway key
issued by `llm-gateway issue`, delivered by the inject path.

Split out of SL-006 (2026-10-18, user's call): satan SL-023's runner calls the
gateway from the host, so no current consumer needs a model path inside the
room. Becomes live when an in-room harness does. Ownership of the gateway
module is still `flakes:IDE-008`'s question.

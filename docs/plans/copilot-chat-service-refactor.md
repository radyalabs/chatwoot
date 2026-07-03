# Refactor Plan: `Captain::Copilot::ChatService`

## Tujuan
Menyederhanakan `app/services/captain/copilot/chat_service.rb` agar kembali fokus sebagai orchestrator domain copilot chat, dengan memindahkan concern yang tidak sejenis ke service/domain object terpisah.

## Latar Belakang
`ChatService` saat ini menangani terlalu banyak tanggung jawab sekaligus:
- Orkestrasi flow utama chat AI
- Validasi eligibility dan pre-check subscription/usage
- Mention policy untuk group chat (channel-specific detail)
- Greeting image processing (base64 + signed blob + size checks)
- Reply persistence dan attachment enqueue
- Handover, conversion, idle conversation lifecycle
- Logging detail lintas concern

Akibatnya:
- Sulit dibaca, diuji, dan diubah tanpa efek samping
- Boundary domain bercampur (business orchestration vs storage/attachment internals)
- Risiko regresi tinggi saat menambah fitur

## Scope
### In Scope
- Refactor bertahap tanpa ubah behavior produk
- Ekstraksi objek/service dari concern besar
- Menjaga contract existing (input/output, side-effects, response format)
- Menjaga kompatibilitas OSS + cek kemungkinan impact enterprise overlay

### Out of Scope
- Redesign total alur copilot
- Ubah API publik
- Ubah semantics bisnis (handover, limit check, welcome flow)
- Penambahan fitur baru

## Target Arsitektur (Incremental)

### 1) `ChatService` (Orchestrator Tipis)
Tetap menjadi entry point:
1. Build context
2. Guard checks
3. Invoke LLM service
4. Route parsed response ke dispatcher

### 2) `Captain::Copilot::EligibilityGuard`
Tanggung jawab:
- `active_conversation?`
- subscription/usage pre-check
- inbox/ai_agent/bot availability
- meaningful payload check

Output:
- result object: `ok?`, `failure_reason`, `failure_code`

### 3) `Captain::Copilot::GroupMentionPolicy`
Tanggung jawab:
- menentukan apakah message group layak diproses AI
- logic mention/reply lookup tetap sama (termasuk format channel saat ini)

Output:
- boolean `allowed?`
- optional `reason_code`

### 4) `Captain::Copilot::GreetingImageSender`
Tanggung jawab:
- baca greeting config
- parse image refs (base64/signed_id)
- attach image ke message
- size checks dan logging teknis media

Output:
- `sent_any?` / `success?`

### 5) `Captain::Copilot::ReplyDispatcher`
Tanggung jawab:
- persist bot reply message
- enqueue attachment async jobs
- standardize additional attributes

### 6) `Captain::Copilot::ConversationStateHandler`
Tanggung jawab:
- handover assignment
- conversion flag update
- idle conversation cleanup + enqueue idle job

## Rencana Implementasi Bertahap (PR kecil)

## PR-1: Extract Group Mention Policy
- Pindahkan:
  - `group_message_without_mention?`
  - `group_conversation?`
  - `bot_mentioned?`
  - `bot_message_replied_to?`
- `ChatService` hanya panggil policy object.

Tujuan: Mengurangi channel-specific logic dari orchestrator.

## PR-2: Extract Greeting Image Sender
- Pindahkan:
  - `send_greeting_images`
  - `send_greeting_image`
  - `attach_base64_image`
  - `attach_signed_id_image`
  - `MAX_GREETING_IMAGE_SIZE`
- Tetap pertahankan fallback behavior existing.

Tujuan: Pisahkan media/storage concern dari chat flow.

## PR-3: Extract Reply Dispatcher
- Pindahkan:
  - `message_created`
  - bagian enqueue `AttachMessageImageJob`
- Pertahankan payload shape yang sama.

Tujuan: Isolasi persistence dan async scheduling.

## PR-4: Extract Eligibility Guard
- Pindahkan:
  - `pre_check_failure_reason`
  - `meaningful_for_ai?`
  - guard-check awal di `perform`
- Gunakan result object agar branch lebih bersih.

Tujuan: Mengurangi branching kompleks pada `perform`.

## PR-5: Extract Conversation State Handler
- Pindahkan:
  - `handover_processing`
  - `conversion_processing`
  - `end_state_processing`
  - `clear_pending_idle_conversation`
  - `find_available_agent`

Tujuan: Pisahkan state transitions dari flow chat utama.

## PR-6: Logging Consolidation Pass
- Rapikan event naming + severity per concern class
- Pastikan tidak ada PII sensitif di log content

Tujuan: observability konsisten dan lebih aman.

## Acceptance Criteria
- Behavior tetap sama (no product regression)
- `ChatService` lebih pendek dan fokus orchestration
- Tiap concern punya class terpisah dan nama domain jelas
- Logging tetap informatif, format konsisten
- Tidak ada perubahan contract API/messages yang terlihat user

## Verification Plan
- Jalankan smoke flow utama:
  - direct message ke copilot
  - group message tanpa mention (harus skip)
  - group message dengan mention/reply (harus lanjut)
  - welcome greeting image flow
  - handover flow
- Jalankan test terkait file yang terdampak (targeted)
- Lint ruby pada file yang berubah

Contoh command verifikasi:
- `bundle exec rspec spec/path/to/copilot/...`
- `bundle exec rubocop app/services/captain/copilot`

## Risiko dan Mitigasi
- Risk: behavior subtle berubah saat extract method
  Mitigasi: PR kecil + parity checks per step
- Risk: coupling tersembunyi antar method
  Mitigasi: extract dengan constructor dependency eksplisit
- Risk: enterprise override drift
  Mitigasi: cek path `enterprise/` untuk service/controller terkait

## Checklist Enterprise Compatibility
- Cari override/extension point yang terkait copilot/chat service di `enterprise/`
- Pastikan contract input/output tidak berubah
- Jika perlu behavior enterprise-only, gunakan extension module bukan hard-fork di OSS

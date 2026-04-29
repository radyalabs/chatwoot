class BroadcastExecutionJob < ApplicationJob
  queue_as :default

  def perform(campaign_id)
    # 1. Ambil data campaign
    campaign = BroadcastCampaign.find_by(id: campaign_id)
    return unless campaign && campaign.draft?

    account = campaign.account
    inbox = campaign.inbox

    # 2. Ubah status menjadi processing
    campaign.processing!
    Rails.logger.info "Mulai Broadcast Campaign ##{campaign.id} | Segmen: #{campaign.target_segment}"

    begin
      # 3. Tentukan Target Kontak (Hanya yang memiliki nomor HP)
      contacts = if campaign.target_segment == 'all'
                   account.contacts.where.not(phone_number: [nil, ''])
                 else
                   # Memanfaatkan relasi acts_as_taggable_on bawaan Chatwoot
                   account.contacts.tagged_with(campaign.target_segment).where.not(phone_number: [nil, ''])
                 end

      if contacts.empty?
        Rails.logger.warn "Broadcast Campaign ##{campaign.id} dibatalkan: Tidak ada kontak di segmen ini."
        campaign.failed!
        return
      end

      # 4. Looping Pengiriman ke setiap kontak
      contacts.find_each do |contact|
        # a. Persiapkan isi pesan
        final_message = process_message_content(campaign, contact)

        # b. Pastikan ada penghubung (ContactInbox) antara Kontak dan Inbox ini
        # source_id untuk WhatsApp biasanya adalah nomor HP kontak
        contact_inbox = ContactInbox.find_or_create_by!(
          contact: contact,
          inbox: inbox,
          source_id: contact.phone_number
        )

        # c. Cari atau buat percakapan (Conversation) baru untuk nomor ini
        conversation = Conversation.find_or_create_by!(
          contact_inbox: contact_inbox,
          inbox: inbox,
          account: account
        ) do |conv|
          conv.contact = contact
        end

        # d. Buat pesan keluar (Outgoing Message). 
        # Di Chatwoot, ketika kita create outgoing message, sistem otomatis akan mengirimkannya ke WA!
        Message.create!(
          account: account,
          inbox: inbox,
          conversation: conversation,
          message_type: :outgoing, # Tipe 1 (Keluar)
          content: final_message
        )

        # e. Jeda aman (Rate Limiting) agar nomor pengirim tidak diblokir/banned oleh WhatsApp
        # Beri jeda 2-3 detik per pesan (bisa disesuaikan)
        sleep 2 
      end

      # 5. Jika semua berhasil, tandai selesai
      campaign.completed!
      Rails.logger.info "Broadcast Campaign ##{campaign.id} berhasil diselesaikan."

    rescue StandardError => e
      # Tangkap error jika ada kesalahan (misal database putus atau error API)
      campaign.failed!
      Rails.logger.error "Broadcast Campaign ##{campaign.id} GAGAL: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

  # Fungsi untuk merakit isi pesan akhir
  def process_message_content(campaign, contact)
    message = campaign.message_body.dup

    # 1. Ganti Variabel Nama (Personalization)
    # (Opsional: Anda bisa menambah variabel lain seperti {{first_name}} di sini)
    message.gsub!('{{full_name}}', contact.name.presence || 'Kak')
    message.gsub!('{{phone_number}}', contact.phone_number.to_s)

    # 2. Proses Spin Text jika diaktifkan (Contoh: "{Halo|Hai|Selamat Pagi}")
    if campaign.spin_text_enabled
      message = parse_spin_text(message)
    end

    # 3. Tambahkan Link Unsubscribe jika diaktifkan
    if campaign.unsubscribe_link_enabled
      message += "\n\n---\nBalas STOP untuk berhenti menerima pesan promosi dari kami."
    end

    message
  end

  # Fungsi untuk mengacak kalimat Spin Text dengan Regex
  def parse_spin_text(text)
    # Mencari pola dalam kurung kurawal, misalnya {Kata1|Kata2|Kata3}
    text.gsub(/\{([^{}]+)\}/) do |match|
      options = $1.split('|') # Memecah berdasarkan garis vertikal
      options.sample          # Mengambil satu kata secara acak
    end
  end
end
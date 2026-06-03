class CaptainListener < BaseListener
  include Singleton

  def message_created(event)
    # Sengaja dikosongkan.
    # Logika debounce dan antrean pesan sekarang sepenuhnya ditangani
    # oleh Captain::Copilot::ChatService dan JangkauDelayJob.
  end
end
class SubscriptionNotifierMailer < ApplicationMailer
  def upcoming_expiry(email, account_id, payment_date, customer_name, nama_paket, tanggal_expired_paket)
    @account_id = account_id
    @payment_date = payment_date
    @customer_name = customer_name
    @nama_paket = nama_paket
    @tanggal_expired_paket = tanggal_expired_paket

    mail(
      to: email,
      subject: "Paket Anda akan berakhir dalam 7 hari - Yuk, perpanjang sekarang!"
    )
  end

  def mau_threshold_warning(email, customer_name, plan_name, account_id, mau_count, mau_limit, threshold_percentage)
    @customer_name = customer_name
    @plan_name = plan_name
    @account_id = account_id
    @mau_count = mau_count
    @mau_limit = mau_limit
    @threshold_percentage = threshold_percentage

    mail(
      to: email,
      subject: mau_subject(threshold_percentage)
    )
  end

  def ai_response_threshold_warning(email, customer_name, plan_name, account_id, ai_count, ai_limit, threshold_percentage)
    @customer_name = customer_name
    @plan_name = plan_name
    @account_id = account_id
    @ai_count = ai_count
    @ai_limit = ai_limit
    @threshold_percentage = threshold_percentage

    mail(
      to: email,
      subject: ai_response_subject(threshold_percentage)
    )
  end

  private

  def mau_subject(threshold)
    case threshold
    when 100
      'Kuota MAU Anda sudah habis - Upgrade paket Anda sekarang'
    when 90
      'Penggunaan MAU Anda sudah mencapai 90% - Segera upgrade paket Anda'
    else
      "Penggunaan MAU Anda sudah mencapai #{threshold}% - Pertimbangkan untuk upgrade paket Anda"
    end
  end

  def ai_response_subject(threshold)
    case threshold
    when 100
      'Kuota AI Response Anda sudah habis - Upgrade paket Anda sekarang'
    when 90
      'Penggunaan AI Response Anda sudah mencapai 90% - Segera upgrade paket Anda'
    else
      "Penggunaan AI Response Anda sudah mencapai #{threshold}% - Pertimbangkan untuk upgrade paket Anda"
    end
  end
end

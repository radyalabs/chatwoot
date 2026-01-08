class Api::V2::Accounts::ReportsController < Api::V1::Accounts::BaseController
  include Api::V2::Accounts::ReportsHelper
  include Api::V2::Accounts::HeatmapHelper

  before_action :check_authorization

  def index
    builder = V2::Reports::Conversations::ReportBuilder.new(Current.account, report_params)
    data = builder.timeseries
    render json: data
  end

  def summary
    render json: build_summary(:summary)
  end

  def bot_summary
    render json: build_summary(:bot_summary)
  end

  def agents
    @report_data = generate_agents_report
    generate_csv('agents_report', 'api/v2/accounts/reports/agents')
  end

  def inboxes
    @report_data = generate_inboxes_report
    generate_csv('inboxes_report', 'api/v2/accounts/reports/inboxes')
  end

  def labels
    @report_data = generate_labels_report
    generate_csv('labels_report', 'api/v2/accounts/reports/labels')
  end

  def teams
    @report_data = generate_teams_report
    generate_csv('teams_report', 'api/v2/accounts/reports/teams')
  end

  def conversation_traffic
    @report_data = generate_conversations_heatmap_report
    timezone_offset = (params[:timezone_offset] || 0).to_f
    @timezone = ActiveSupport::TimeZone[timezone_offset]

    generate_csv('conversation_traffic_reports', 'api/v2/accounts/reports/conversation_traffic')
  end

  def conversations
    return head :unprocessable_entity if params[:type].blank?
    data = {}

    data[:open] = Current.account.conversations.where(status: 'open').count
    data[:unassigned] = Current.account.conversations.where(status: 'open', assignee_id: nil).count

    render json: data
  end

  def bot_metrics
    bot_metrics = V2::Reports::BotMetricsBuilder.new(Current.account, params).metrics
    render json: bot_metrics
  end

  def ai_agent_metrics
    ai_agent_metrics = V2::Reports::AiAgentMetricsBuilder.new(Current.account, params).metrics
    render json: ai_agent_metrics
  end

  def credit_usage
    inbox_ids = Current.account.inboxes.pluck(:id)

    bot_agent_id = AgentBotInbox.where(inbox_id: inbox_ids).pluck(:ai_agent_id).first
    
    ai_count = 0
    if bot_agent_id
      ai_count = Current.account.conversations.where(status: 'resolved', assignee_id: bot_agent_id).count
    end

    render json: {
      ai_responses: ai_count 
    }
  end

  def funnel_metrics
    # 1. Range Waktu
    range = if params[:since].present? && params[:until].present?
              Time.at(params[:since].to_i)..Time.at(params[:until].to_i)
            else
              7.days.ago..Time.current
            end

    conversations = Current.account.conversations.where(created_at: range)
    messages = Current.account.messages.where(created_at: range)

    # --- DEFINISI KATA KUNCI (DICTIONARY) ---
    high_intent_keywords = [
      'beli', 'order', 'pesan', 'bayar', 'transfer', 'tf', 'trf', 'rek', 'rekening', 
      'norek', 'payment', 'lunas', 'qris', 'cod', 'invoice', 'nota', 'checkout',
      
      'harga', 'berapa', 'brp', 'biaya', 'price', 'pricelist', 'diskon', 'promo',
      
      'stok', 'ready', 'ada gak', 'tersedia', 'warna', 'ukuran', 'size', 'spek', 
      'garansi', 'ori', 'original', 'realpic',
      
      'ongkir', 'kirim', 'sampai', 'resi', 'kurir', 'alamat', 'lokasi'
    ]

    sql_query = high_intent_keywords.map { |w| "%#{w}%" }

    total_starter = conversations.count

    engaged_conversation_ids = messages.where(sender_type: 'Contact')
                                       .reorder(nil)
                                       .select(:conversation_id)
                                       .distinct
    engage_user = conversations.where(id: engaged_conversation_ids).count

    high_intent_conversation_ids = messages.where(sender_type: 'Contact')
                                           .where("content ILIKE ANY (array[?])", sql_query)
                                           .reorder(nil)
                                           .select(:conversation_id)
                                           .distinct
                                           
    high_intent = conversations.where(id: high_intent_conversation_ids).count

    resolved_conversations = conversations.where(status: :resolved)
    
    inbox_ids = Current.account.inboxes.pluck(:id)
    bot_agent_id = AgentBotInbox.where(inbox_id: inbox_ids).pluck(:ai_agent_id).first
    
    if bot_agent_id
      assisted_bot = resolved_conversations.where(assignee_id: bot_agent_id).count
      assisted_cs  = resolved_conversations.where.not(assignee_id: bot_agent_id).count
    else
      assisted_bot = 0
      assisted_cs  = resolved_conversations.count
    end

    repeat_buyer = Current.account.contacts.where(created_at: range)
                     .where("CAST(additional_attributes ->> 'conversations_count' AS INTEGER) > ?", 1)
                     .count

    render json: {
      total_starter: total_starter,
      engage_user: engage_user,
      high_intent: high_intent,
      assisted_bot: assisted_bot,
      assisted_cs: assisted_cs,
      repeat_buyer: repeat_buyer
    }
  end

  def trend_metrics
    start_date = params[:since] ? Time.at(params[:since].to_i).to_date : 6.days.ago.to_date
    end_date = params[:until] ? Time.at(params[:until].to_i).to_date : Date.today

    inbox_ids = Current.account.inboxes.pluck(:id)
    bot_agent_id = AgentBotInbox.where(inbox_id: inbox_ids).pluck(:ai_agent_id).first

    data_points = []

    (start_date..end_date).each do |date|
      daily_convos = Current.account.conversations.where(created_at: date.beginning_of_day..date.end_of_day)
      
      total = daily_convos.count
      bot   = bot_agent_id ? daily_convos.where(assignee_id: bot_agent_id).count : 0
      agent = total - bot

      data_points << {
        timestamp: date.to_time.to_i,
        total: total,
        bot: bot,
        agent: agent
      }
    end

    render json: data_points
  end

  def conversation_traffic
    # Ambil data dari helper
    @report_data = generate_conversations_heatmap_report
    
    # Langsung kirim sebagai JSON ke frontend
    render json: @report_data
  end

  def handover_metrics
    range = Time.at(params[:since].to_i)..Time.at(params[:until].to_i)
    
    inbox_ids = Current.account.inboxes.pluck(:id)
    bot_agent_id = AgentBotInbox.where(inbox_id: inbox_ids).pluck(:ai_agent_id).first
    
    total_handovers = 0
    handover_rate = 0
    top_agents = []
    
    if bot_agent_id
      bot_conv_ids = Current.account.messages.where(created_at: range, sender_id: bot_agent_id)
                                             .reorder(nil) 
                                             .select(:conversation_id).distinct
      
      total_bot_chats = bot_conv_ids.count
      
      handover_convs = Current.account.conversations.where(id: bot_conv_ids)
                                                  .where.not(assignee_id: [nil, bot_agent_id])
      
      total_handovers = handover_convs.count
      
      handover_rate = total_bot_chats > 0 ? ((total_handovers.to_f / total_bot_chats) * 100).round(0) : 0
      
      top_agents = handover_convs.group(:assignee_id).count.map do |agent_id, count|
        user = User.find_by(id: agent_id)
        next unless user
        { 
          name: user.name, 
          count: count, 
          percentage: ((count.to_f / total_handovers) * 100).round(0) 
        }
      end.compact.sort_by { |x| -x[:count] }.first(3)
    end

    render json: {
      totalHandover: total_handovers,
      handoverRate: handover_rate,
      byAgent: top_agents,
      reasons: {
        labels: ['Klien meminta CS', 'Bot tidak mengerti', 'Isu Teknis'],
        data: [60, 30, 10], 
        colors: ['#389947', '#86EFAC', '#D1FAE5']
      }
    }
  end

  def agents_daily_metrics
     range = Time.at(params[:since].to_i)..Time.at(params[:until].to_i)
     start_date = range.begin.to_date
     end_date = range.end.to_date
     
     labels = (start_date..end_date).map { |d| d.strftime("%d/%m") }
     datasets = []
     
     top_agent_ids = Current.account.conversations.where(created_at: range)
                                    .group(:assignee_id).order('count_all DESC')
                                    .limit(5).count.keys.compact
     
     User.where(id: top_agent_ids).each do |agent|
       data = []
       (start_date..end_date).each do |date|
         cnt = Current.account.conversations.where(assignee_id: agent.id, 
                                                 created_at: date.beginning_of_day..date.end_of_day).count
         data << cnt
       end
       datasets << { label: agent.name, data: data }
     end
     
     render json: { labels: labels, datasets: datasets }
  end

  def agent_performance_metrics
    range = Time.at(params[:since].to_i)..Time.at(params[:until].to_i)
    
    agent_ids = Current.account.conversations.where(created_at: range)
                               .where.not(assignee_id: nil)
                               .select(:assignee_id).distinct
    agents = User.where(id: agent_ids)
    
    data = agents.map do |agent|
      convos = Current.account.conversations.where(assignee_id: agent.id, created_at: range)
      total = convos.count
      resolved = convos.where(status: :resolved).count
      
      {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        thumbnail: agent.avatar_url,
        metric: {
          conversations_count: total,
          resolution_rate: total > 0 ? ((resolved.to_f / total) * 100).round(1) : 0,
          work_distribution: 0,
          avg_first_response_time: "0m",
          avg_resolution_time: "0m" 
        }
      }
    end
    render json: data
  end

  private

  def generate_csv(filename, template)
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = "attachment; filename=#{filename}.csv"
    render layout: false, template: template, formats: [:csv]
  end

  def check_authorization
    return if Current.account_user.administrator?

    raise Pundit::NotAuthorizedError
  end

  def common_params
    {
      type: params[:type].to_sym,
      id: params[:id],
      group_by: params[:group_by],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
    }
  end

  def current_summary_params
    common_params.merge({
                          since: range[:current][:since],
                          until: range[:current][:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def previous_summary_params
    common_params.merge({
                          since: range[:previous][:since],
                          until: range[:previous][:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def report_params
    common_params.merge({
                          metric: params[:metric],
                          since: params[:since],
                          until: params[:until],
                          timezone_offset: params[:timezone_offset]
                        })
  end

  def conversation_params
    {
      type: params[:type].to_sym,
      user_id: params[:user_id],
      page: params[:page].presence || 1
    }
  end

  def range
    {
      current: {
        since: params[:since],
        until: params[:until]
      },
      previous: {
        since: (params[:since].to_i - (params[:until].to_i - params[:since].to_i)).to_s,
        until: params[:since]
      }
    }
  end

  def build_summary(method)
    builder = V2::Reports::Conversations::MetricBuilder
    current_summary = builder.new(Current.account, current_summary_params).send(method)
    previous_summary = builder.new(Current.account, previous_summary_params).send(method)
    current_summary.merge(previous: previous_summary)
  end

  def build_summary_ai_agent(method); end

  def conversation_metrics
    V2::ReportBuilder.new(Current.account, conversation_params).conversation_metrics
  end
end

Api::V2::Accounts::ReportsController.prepend_mod_with('Api::V2::Accounts::ReportsController')

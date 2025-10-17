class Api::V2::Agents::OperationalHoursController < ApplicationController
# class Api::V2::Agents::OperationalHoursController < Api::BaseController
  def index
    agent_bot_id = params[:agent_id]
    operational_hours = OperationalHour.where(agent_bot_id: agent_bot_id)

    response = operational_hours.map do |operational_hour|
      {
        id: operational_hour.id,
        day_of_week: operational_hour.day_of_week,
        open_allday: operational_hour.open_allday,
        close_allday: operational_hour.close_allday,
        start_time: format_time(operational_hour.open_hour, operational_hour.open_minute),
        end_time: format_time(operational_hour.close_hour, operational_hour.close_minute)
      }
    end

    render json: response
  end

  def show
    agent_bot_id = params[:agent_id]
    operational_hour = OperationalHour.find_by(agent_bot_id: agent_bot_id, id: params[:id])

    raise ActiveRecord::RecordNotFound if operational_hour.nil?

    render json: {
      day_of_week: operational_hour.day_of_week,
      open_allday: operational_hour.open_allday,
      close_allday: operational_hour.close_allday,
      start_time: format_time(operational_hour.open_hour, operational_hour.open_minute),
      end_time: format_time(operational_hour.close_hour, operational_hour.close_minute)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'OperationalHour not found' }, status: :not_found
  end

  def create
    operational_hour = OperationalHour.new(operational_hour_params)
    operational_hour.agent_bot_id = params[:agent_id]

    if operational_hour.save
      render json: {
        id: operational_hour.id,
        day_of_week: operational_hour.day_of_week,
        open_allday: operational_hour.open_allday,
        close_allday: operational_hour.close_allday,
        start_time: format_time(operational_hour.open_hour, operational_hour.open_minute),
        end_time: format_time(operational_hour.close_hour, operational_hour.close_minute)
      }, status: :created
    else
      render json: { errors: operational_hour.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    agent_bot_id = params[:agent_id]
    operational_hour = OperationalHour.find_by(agent_bot_id: agent_bot_id, id: params[:id])

    # Raise an error if day_of_week is being changed
    if operational_hour.day_of_week.to_s != operational_hour_params[:day_of_week].to_s
      raise ActionController::BadRequest, "Changing 'day_of_week' is not allowed."
    end

    if operational_hour.update(operational_hour_params)
      render json: {
        id: operational_hour.id,
        day_of_week: operational_hour.day_of_week,
        open_allday: operational_hour.open_allday,
        close_allday: operational_hour.close_allday,
        start_time: format_time(operational_hour.open_hour, operational_hour.open_minute),
        end_time: format_time(operational_hour.close_hour, operational_hour.close_minute)
      }
    else
      render json: { errors: operational_hour.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'OperationalHour not found' }, status: :not_found
  rescue ActionController::BadRequest => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def operational_hour_params
    params.require(:operational_hour).permit(:day_of_week, :open_hour, :open_minute, :close_hour, :close_minute, :open_allday, :close_allday)
  end

  # Helper method to format the time
  def format_time(hour, minute)
    Time.new(2000, 1, 1, hour, minute).strftime("%H:%M") # Assuming fixed date
  end
end

FactoryBot.define do
  factory :operational_hour do
    agent_bot { nil }
    day_of_week { 1 }
    open_hour { 1 }
    open_minute { 1 }
    close_hour { 1 }
    close_minute { 1 }
    open_allday { false }
    close_allday { false }
  end
end

require 'administrate/field/base'

class BrowserDatetimeField < Administrate::Field::Base
  # def to_s
  #   data
  # end
  def formatted
    return '-' if data.blank?

    data.strftime('%d %b %Y, %H.%M %Z')
  end
end

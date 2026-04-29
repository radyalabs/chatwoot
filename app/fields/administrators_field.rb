require 'administrate/field/has_many'

class AdministratorsField < Administrate::Field::HasMany
  def self.permitted_attribute(attr, _options = nil)
    { "#{name}_attributes".to_sym => { id: :integer, _destroy: :boolean } }
  end
end

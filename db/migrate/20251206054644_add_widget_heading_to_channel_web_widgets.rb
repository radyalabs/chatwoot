class AddWidgetHeadingToChannelWebWidgets < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_web_widgets, :widget_heading, :string
  end
end

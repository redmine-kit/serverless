# frozen_string_literal: true

class CreateDerivedSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :derived_samples do |t|
      t.string :name
    end
  end
end

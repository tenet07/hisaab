# Background jobs, cache and Action Cable tables in the main database, so the whole app runs
# on a single Postgres (a small server or a free hosting plan).
class CreateSolidTables < ActiveRecord::Migration[8.0]
  def up
    %w[queue cache cable].each do |name|
      body = File.read(Rails.root.join("db/#{name}_schema.rb"))[/define\(version: [\d_]+\) do\n(.*)end\s*\z/m, 1]
      instance_eval(body)
    end
  end

  def down
    (connection.tables.grep(/\Asolid_(queue|cache|cable)_/)).each { drop_table _1, force: :cascade }
  end
end

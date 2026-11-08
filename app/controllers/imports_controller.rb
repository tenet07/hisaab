class ImportsController < ApplicationController
  before_action :require_owner_or_accounts!
  KINDS = Importer::COLUMNS.keys.map(&:to_s).freeze
  DIR = Rails.root.join("tmp/imports")

  def index; end

  def template
    kind = params[:kind].to_s
    return head(:not_found) unless KINDS.include?(kind)
    send_data Importer.template_csv(kind.to_sym), filename: "#{kind}-template.csv", type: "text/csv"
  end

  # Upload → preview (nothing saved yet).
  def create
    kind = params[:kind].to_s
    file = params[:file]
    raise Books::Error, "Choose what you're importing" unless KINDS.include?(kind)
    raise Books::Error, "Choose a file" unless file.respond_to?(:original_filename)
    ext = File.extname(file.original_filename).downcase
    raise Books::Error, "Upload an Excel (.xlsx) or CSV file" unless %w[.xlsx .csv].include?(ext)
    raise Books::Error, "File too large (max 5 MB)" if file.size > 5.megabytes

    FileUtils.mkdir_p(DIR)
    token = SecureRandom.hex(12)
    FileUtils.cp(file.tempfile.path, DIR.join("#{token}#{ext}"))
    session[:import] = { "token" => token, "ext" => ext, "kind" => kind, "name" => file.original_filename }
    @result = Importer.new(kind, DIR.join("#{token}#{ext}").to_s, user: current_user).run(commit: false)
    @file_name = file.original_filename
    render :preview
  end

  # Save the previewed file (all rows or nothing).
  def commit
    imp = session[:import] or raise Books::Error, "Upload the file again"
    path = DIR.join("#{imp['token']}#{imp['ext']}")
    raise Books::Error, "Upload the file again" unless File.exist?(path)
    @result = Importer.new(imp["kind"], path.to_s, user: current_user).run(commit: true)
    if @result.committed
      File.delete(path)
      session.delete(:import)
      c = @result.counts
      redirect_to imports_path, notice: "Imported #{imp['kind']}: #{c['new'].to_i} new, #{c['update'].to_i} updated"
    else
      @file_name = imp["name"]
      flash.now[:alert] = "Nothing was saved. Fix the rows marked below and upload again."
      render :preview, status: :unprocessable_entity
    end
  end
end

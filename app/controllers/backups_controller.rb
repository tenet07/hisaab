# Owner downloads the nightly database backups, so a copy lives off the server
# (on a phone, laptop or Google Drive) without anyone typing commands.
class BackupsController < ApplicationController
  NAME = /\Ashopos-\d{4}-\d{2}-\d{2}_\d{4}\.sqlite3\z/
  before_action { redirect_to(root_path, alert: "Only the owner can download backups") unless current_user.owner? }

  def self.dir = Pathname(ENV.fetch("BACKUP_DIR", "/backups"))
  def self.files
    return [] unless dir.directory?
    dir.children.select { _1.file? && _1.basename.to_s.match?(NAME) }.sort_by(&:mtime).reverse
  end

  def index
    @files = self.class.files
    @stale = @files.empty? || @files.first.mtime < 36.hours.ago
  end

  def show
    name = params[:id].to_s
    path = self.class.dir.join(name)
    return head(:not_found) unless name.match?(NAME) && path.file?
    send_file path, filename: name, type: "application/octet-stream"
  end
end

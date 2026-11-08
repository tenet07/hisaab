class ClaimsController < ApplicationController
  before_action :require_office!
  def index
    @claims = Claim.includes(lines: :product).order(created_at: :desc)
    @awaiting = Product.order(:brand, :name).map { |p| [p, p.stock(:awaiting_claim)] }.select { |_, q| q.positive? }
                       .group_by { |p, _| p.brand }
  end
  def show = @claim = Claim.includes(lines: :product).find(params[:id])
  def create
    claim = Books.send_claim(brand: params[:brand], user: current_user)
    redirect_to claim, notice: "Claim #{claim.number} created; pieces moved to 'with brand'"
  end
end

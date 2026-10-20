class ReplacementsController < ApplicationController
  require_permission :replacements
  before_action :require_writer!, except: %i[index show warranty]

  def index
    scope = Replacement.includes(:customer, :product, :brand_claim).recent
    scope = scope.where(claim_status: params[:status]) if params[:status].present?
    scope = scope.joins(:product).where(products: { brand_id: params[:brand_id] }) if params[:brand_id].present?
    @replacements = scope.limit(300)
    @counts = Replacement.group(:claim_status).count
  end

  def show = @replacement = Replacement.find(params[:id])

  def new
    @customer = Customer.find_by(id: params[:customer_id])
  end

  # JSON for the intake screen: which invoice sold it and is it still in warranty?
  def warranty
    if params[:customer_id].present? && params[:product_id].present?
      info = Replacements::Intake.lookup(Customer.find(params[:customer_id]), Product.find(params[:product_id]))
      render json: { invoice: info[:invoice]&.number, invoice_id: info[:invoice]&.id, sold_on: info[:sold_on]&.strftime("%d %b %Y"),
                     warranty_until: info[:warranty_until]&.strftime("%d %b %Y"), valid: info[:valid],
                     stock: Product.find(params[:product_id]).stock }
    else
      render :warranty
    end
  end

  def create
    r = Replacements::Intake.call(customer: Customer.find(params.require(:customer_id)), product: Product.find(params.require(:product_id)),
                                  outcome: params[:outcome], invoice: (Invoice.find_by(id: params[:invoice_id]) if params[:invoice_id].present?),
                                  defect: params[:defect], serial_no: params[:serial_no], goodwill: params[:goodwill] == "1",
                                  channel: Current.user.mobile_first? ? "route" : "counter", client_uuid: params[:client_uuid])
    if r.outcome == "charged" && can?(:invoice_post)
      return redirect_to(new_invoice_path(customer_id: r.customer_id), notice: "Logged #{r.number}. Bill the new piece now.")
    end
    redirect_to r, notice: r.outcome == "swapped" ? "Swapped. Defective piece is in “awaiting claim”." : "Logged #{r.number}."
  end

  def write_off
    r = Replacement.find(params[:id])
    Replacements::WriteOff.request!(r, reason: params[:reason].presence || "Cannot be claimed")
    redirect_to r, notice: "Write-off sent to the owner for approval."
  end
end

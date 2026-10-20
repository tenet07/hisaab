class BrandClaimsController < ApplicationController
  require_permission :claims
  before_action(except: %i[index show challan]) { authorize!(:claims_edit) unless Current.user.owner? }
  before_action :set_claim, only: %i[show send_claim settle challan]

  def index
    @claims = BrandClaim.includes(:brand, replacements: :product).recent
    @awaiting = Replacement.awaiting.where(brand_claim_id: nil).includes(product: :brand).group_by { _1.product.brand }
  end

  def show; end

  def new
    @brand = Brand.find(params[:brand_id])
    @pieces = Replacement.awaiting.where(brand_claim_id: nil).joins(:product).where(products: { brand_id: @brand.id }).includes(:product, :customer)
  end

  def create
    brand = Brand.find(params[:brand_id])
    claim = Claims::Batch.build(brand, Replacement.where(id: params[:replacement_ids]).includes(:product).to_a)
    redirect_to claim, notice: "Claim #{claim.number} batched with #{claim.pieces} pieces. Print the challan and send it."
  end

  def send_claim
    Claims::Batch.dispatch!(@claim, challan_no: params[:challan_no], sent_on: date_param(params[:sent_on]))
    redirect_to @claim, notice: "Marked sent. Pieces moved to “with brand”."
  end

  def settle
    outcomes = (params[:outcomes]&.to_unsafe_h || {}).transform_values do |o|
      { result: o["result"], amount_paise: Money.to_paise(o["amount"]).to_i }
    end
    Claims::Batch.settle!(@claim, outcomes: outcomes, credit_note_ref: params[:credit_note_ref], date: date_param(params[:settled_on]))
    redirect_to @claim, notice: @claim.reload.settled? ? "Claim fully settled." : "Partial settlement recorded; remaining pieces stay with the brand."
  end

  def challan
    send_data ChallanPdf.new(@claim).render, filename: "challan-#{@claim.number.tr('/', '-')}.pdf", type: "application/pdf", disposition: "inline"
  end

  private

  def set_claim = @claim = BrandClaim.find(params[:id])
end

class ReplacementsController < ApplicationController
  def index = @replacements = Replacement.includes(:customer, :product, :user).order(created_at: :desc).limit(100)
  def new
    @customer = Customer.find_by(id: params[:customer_id])
    @customers = Customer.order(:name)
    @products = Product.where("warranty_months > 0").order(:brand, :name)
  end
  def create
    r = Books.replace(customer: Customer.find(params[:customer_id]), product: Product.find(params[:product_id]),
                      qty: [params[:qty].to_i, 1].max, user: current_user,
                      sold_on: params[:sold_on].presence && Date.parse(params[:sold_on]),
                      invoice_number: params[:invoice_number], note: params[:note],
                      override: params[:override] == "1")
    redirect_to(current_user.field? ? visit_customer_path(r.customer) : replacements_path,
                notice: "Replaced #{r.qty} × #{r.product.label}#{' (owner approved, out of warranty)' unless r.in_warranty}")
  end
end

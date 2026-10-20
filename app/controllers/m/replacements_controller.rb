module M
  class ReplacementsController < BaseController
    def new = @customer = Customer.find(params[:customer_id])

    def create
      r = Mobile::Capture.replacement(customer: Customer.find(params[:customer_id]), product_id: params[:product_id], outcome: params[:outcome],
                                      defect: params[:defect], client_uuid: params[:client_uuid])
      redirect_to m_customer_path(r.customer), notice: "Replacement #{r.number} logged (#{r.warranty_valid ? 'in warranty' : 'out of warranty'})."
    end
  end
end

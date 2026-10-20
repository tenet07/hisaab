# Daily: remind customers with overdue bills (at most once a week each).
class OverdueRemindersJob < ApplicationJob
  def perform
    Current.device = "scheduler"
    recent = WhatsappMessage.where(template: "overdue_reminder", created_at: 7.days.ago..).pluck(:customer_id).to_set
    Invoice.posted.where(due_date: ...Date.current).includes(:customer).map(&:customer).uniq.each do |c|
      next if recent.include?(c.id) || c.overdue_paise.zero?
      WhatsappNotifier.overdue_reminder(c)
    end
  end
end

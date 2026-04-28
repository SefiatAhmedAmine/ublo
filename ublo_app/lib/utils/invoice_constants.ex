defmodule MyApp.InvoiceConstants do
  def state do
    [
      :draft,
      :uploading,
      :failed,
      :completed
    ]
  end

  def provider do
    [
      :digital_ocean,
      :pandadoc,
      :uploadcare
    ]
  end

  def invoice_documents_type do
    [
      :custom_invoice_notice,
      :custom_credit_note_notice,
      :custom_invoice_receipt,
      :payment_notice,
      :rent_receipt,
      :warranty_deposit_notice,
      :warranty_deposit_receipt
    ]
  end
end

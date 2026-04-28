# Ublo Pennylane Export

Elixir service for exporting completed invoice notices to Pennylane through an
Oban-backed queue.

## Pennylane Configuration

Set `PENNYLANE_API_KEY` in the runtime environment for real exports. The default
endpoint is Pennylane's e-invoice import endpoint:

- `PENNYLANE_API_KEY`: bearer token used by `MyApp.PennylaneClient`.
- `:pennylane_e_invoices_import_url`: configured in `ublo_app/config/config.exs`.
- `:pennylane_request_options`: Req options, including upload timeout.

When an invoice transitions to `:completed`, `InvoiceService.update/1` enqueues
an export job if the invoice is a non-exported `:custom_invoice_notice` with a
PDF reference. Export attempts are recorded in `invoice_exports`.


-ifndef(TASK_MODULES_HRL).
-define(TASK_MODULES_HRL, 'true').

-define(TASKS, [
    'kt_bill_early',
    'kt_cleanup',
    'kt_fax_cleanup',
    'kt_initial_occurrence',
    'kt_ledger_rollover',
    'kt_low_balance',
    'kt_modb',
    'kt_modb_creation',
    'kt_numbers',
    'kt_port_requests',
    'kt_rates',
    'kt_resource_selectors',
    'kt_services',
    'kt_services_rollover',
    'kt_task_worker',
    'kt_task_worker_noinput',
    'kt_token_auth',
    'kt_user_auth',
    'kt_webhooks'
]).

-endif.

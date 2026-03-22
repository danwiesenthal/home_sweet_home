# Privacy Tagging for Task Routing

## Concept

Tasks carry metadata about what data they touch. Model runners have attributes specifying what data they're authorized to access. A local model running on-device might be authorized to access personal data (OmniFocus tasks, calendar, email), while a cloud model might not.

The scheduler then has a constraint satisfaction problem: match tasks to model runners that satisfy both capability requirements (model size, intelligence level) and privacy requirements (data access authorization).

## Example

A task tagged `privacy: local_only` can only run on local model infrastructure. A task tagged `privacy: public` can run anywhere. A task tagged `privacy: authorized_cloud` can run on cloud models from providers with appropriate data processing agreements.

This is not implemented yet. The task schema should reserve space for these attributes so they can be added without restructuring.

# Agentforce - Custom Web Search w Perplexity

A reusable Perplexity web-search action package with Flow wrappers, Apex callout classes, tests, a formatting prompt template, and credential metadata.

This repository contains the Salesforce DX source retrieved from the `Agentforce - Custom Web Search w Perplexity` unmanaged 1GP package hosted in the `pamigration` org. It is intended to be deployable as source-controlled metadata and to serve as implementation documentation for the solution.

## Solution Highlights
- Provides separate Agentforce actions for Perplexity Search and Perplexity Chat Completions.
- Uses the Perplexity_API Named Credential and Perplexity_API_EC External Credential.
- Includes Apex tests for the Perplexity search/chat helper classes.

## Architecture
Typical execution path:

1. An Agentforce action or topic receives a user request.
2. The action invokes a Flow, Prompt Builder template, or Apex invocable target.
3. Supporting Apex, Prompt Builder templates, and Salesforce metadata perform the callout, extraction, generation, formatting, or record update.
4. The result is returned to Agentforce or stored in Salesforce records for follow-up work.

## Metadata Inventory
- GenAiFunctions: `Web_Search_w_Perplexity_Chat_Completions`, `Web_Search_w_Perplexity_Search`
- Prompt templates: `Web_Search_w_Perplexity`
- Flows: `Web_Search_w_Perplexity_Chat_Completions`, `Web_Search_w_Perplexity_Search`
- Apex classes: `Web_Search_w_Perplexity_Chat`, `Web_Search_w_Perplexity_Search`, `Web_Search_w_Perplexity_Util`
- Apex tests: `Web_Search_w_Perplexity_Chat_Test`, `Web_Search_w_Perplexity_Search_Test`, `Web_Search_w_Perplexity_Util_Test`
- Integration metadata: 2 credential/remote-site component(s)
- Permission sets: `Perplexity_API_Access`

## Agentforce Actions and Topics
- `Web_Search_w_Perplexity_Chat_Completions` -> `Web_Search_w_Perplexity_Chat_Completions` (flow) - Use this action for web search. This action returns reliable and accurate information from the open internet using Perplexity Web Search.
- `Web_Search_w_Perplexity_Search` -> `Web_Search_w_Perplexity_Search` (flow) - Use this action for web search. This action returns reliable and accurate information from the open internet using Perplexity Web Search.

## Flows
- `Web_Search_w_Perplexity_Chat_Completions` (Web Search w/ Perplexity Chat Completions) status `Active` type `AutoLaunchedFlow` - This is the flow that makes API calls to the Perplexity Chat Completions endpoint for custom web search use cases. Key actions: Custom Web Search Prompt (generatePromptResponse: Web_Search_w_Perplexity), Web Search w/ Perplexity Chat Completions (apex: Web_Search_w_Perplexity_Chat).
- `Web_Search_w_Perplexity_Search` (Web Search w/ Perplexity Search) status `Active` type `AutoLaunchedFlow` - The flow allow Agentforce to use custom web search with Perplexity API Search endpoints. Allows greater control over search results and allowed sources. Key actions: Custom Web Search Prompt (generatePromptResponse: Web_Search_w_Perplexity), Web Search w/ Perplexity Search (apex: Web_Search_w_Perplexity_Search).

## Prompt Templates
- `Web_Search_w_Perplexity` - This prompt template helps generate an answer from custom web search with perplexity (3 version(s); statuses: Published; inputs: `Search_Query`, `Perplexity_Search_Results`)

## Apex
Apex runtime classes: `Web_Search_w_Perplexity_Chat`, `Web_Search_w_Perplexity_Search`, `Web_Search_w_Perplexity_Util`

Apex test classes: `Web_Search_w_Perplexity_Chat_Test`, `Web_Search_w_Perplexity_Search_Test`, `Web_Search_w_Perplexity_Util_Test`

Invocable methods and key callouts:
- Web_Search_w_Perplexity_Chat: Perplexity: Chat Completions
- Web_Search_w_Perplexity_Search: Perplexity: Search
- Observed endpoints: `callout:Perplexity_API/chat/completions`, `https://www.NASA.gov/path`, `callout:Perplexity_API/search`, `https://a.example`, `https://example.com/test`, `https://www.Example.com/path`

## Data Model and UI
- None retrieved.

## Integrations and Credentials
- Named Credential `Perplexity_API`
- External Credential `Perplexity_API_EC` using Custom; parameters: API_Key (NamedPrincipal), Authorization (AuthHeader)
- Apex endpoints/callouts observed: `callout:Perplexity_API/chat/completions`, `https://www.NASA.gov/path`, `callout:Perplexity_API/search`, `https://a.example`, `https://example.com/test`, `https://www.Example.com/path`

No credential secret values were included in the retrieved metadata. Any API keys or named-principal secrets must be configured in the target org after deployment.

## Prerequisites
- Salesforce org with Metadata API support and Salesforce CLI access.
- Agentforce and Prompt Builder features enabled for metadata that uses GenAiFunction, GenAiPlugin, or GenAiPromptTemplate.
- Permission to deploy Apex, Flow, Prompt Builder, Named Credential, External Credential, and custom object metadata as applicable.
- Access to any external API provider used by this package.

## Deployment
Authenticate to the target org, then validate first:

```bash
sf org login web --alias <target-org>
sf project deploy start --dry-run --manifest manifest/package.xml --target-org <target-org> --wait 30 --test-level RunSpecifiedTests --tests Web_Search_w_Perplexity_Chat_Test,Web_Search_w_Perplexity_Search_Test,Web_Search_w_Perplexity_Util_Test
```

Deploy after the dry run succeeds:

```bash
sf project deploy start --manifest manifest/package.xml --target-org <target-org> --wait 30 --test-level RunSpecifiedTests --tests Web_Search_w_Perplexity_Chat_Test,Web_Search_w_Perplexity_Search_Test,Web_Search_w_Perplexity_Util_Test
```

## Post-Deploy Setup
- Configure the Perplexity_API_EC external credential with a named principal API key.
- Assign the Perplexity_API_Access permission set to users or integration users who run the action.
- Run the included Apex tests after credential setup.
- Add the GenAiFunctions to the intended Agentforce topic/action library.

## Testing and Validation
- Run a metadata dry run before deploying to a shared org.
- Run Apex tests listed above when present.
- Open each Flow in Flow Builder and confirm it is active or activate it after reviewing org-specific references.
- Open Prompt Builder templates and confirm the expected published version, model, and inputs.
- Test the Agentforce action with a low-risk sample prompt before giving it to end users.

## Package Provenance
- Source package: `Agentforce - Custom Web Search w Perplexity`
- MetadataPackageId: `033Hn000000hPbiIAE`
- Retrieved from org alias: `pamigration`
- Package versions observed: `1.0.0 Beta (Fall 2025)`, `1.1.0 Beta (Fall 2025)`, `1.2.0 Beta (Fall 2025)`
- Repository name: `agentforce-custom-web-search-w-perplexity`

## Notes for Maintainers
- Keep generated secrets, local org auth files, `.sf`, `.sfdx`, and deployment output out of source control.
- Treat prompt templates and Agentforce action descriptions as production behavior, not just documentation.
- For production hardening, prefer Named Credential and External Credential patterns over passing API keys directly through Flow variables.

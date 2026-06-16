# Arcanum-Reticulum-Experimentum

This repository deploys a full Azure lab environment through Terraform and is intended to be safely re-run from GitHub workflows for create and update operations.

## Workflow Notes and Considerations
The workflows for this repository were created with some design considerations to optimize the operation within the GitHub environment.
- **Splitting of Operational Activities and Workflows** - Certain operations are going to need to have internal access within the environment because this is a fully self-contained container operations environment. Other operations can interface with the environment externally to the cloud API instead of having to be internal to the network. As GitHub Runners that use the Hosted Computer Networking feature are needed but they are also billed diretly for runtime minutes, the loads were split up to help handle the situation. This helps minimize billing for the features to what is necessary for those deployments.
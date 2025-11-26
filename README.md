# Security Reports - Azure Infrastructure

This directory contains the Azure Bicep templates for deploying the Security Reports application infrastructure.

## Architecture

The infrastructure consists of:

- **Azure Cosmos DB Account**: NoSQL database for storing security data
- **Cosmos DB Database**: Container for all security-related collections
- **Cosmos DB Containers**: Separate containers for CVEs, identity data, and device data
- **Log Analytics Workspace**: For monitoring and diagnostics (optional)

## Security Features

✅ **Network Security**

- Public access disabled by default
- IP address filtering support
- Virtual network integration ready

✅ **Data Protection**

- Automatic backups with geo-redundancy
- Encryption at rest and in transit
- Key-based metadata write access disabled

✅ **Monitoring**

- Diagnostic settings for comprehensive logging
- Query performance monitoring
- Partition key statistics

## Quick Start

### Prerequisites

- Azure CLI installed and configured
- Appropriate Azure permissions for resource deployment
- PowerShell (for deployment script)

### Deployment

1. **Development Environment**:

   ```powershell
   .\deploy.ps1 -Environment dev -ResourceGroupName "rg-secreports-dev"
   ```

2. **Production Environment**:

   ```powershell
   .\deploy.ps1 -Environment prod -ResourceGroupName "rg-secreports-prod"
   ```

3. **What-If Analysis**:

   ```powershell
   .\deploy.ps1 -Environment dev -ResourceGroupName "rg-secreports-dev" -WhatIf
   ```

### Manual Deployment

```bash
# Create resource group
az group create --name "rg-secreports-dev" --location "East US"

# Deploy infrastructure
az deployment group create \
  --resource-group "rg-secreports-dev" \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

## Configuration

### Environment Parameters

- **dev.bicepparam**: Development environment settings
- **prod.bicepparam**: Production environment settings

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `location` | Azure region | `resourceGroup().location` |
| `databaseThroughput` | Database-level RU/s | `400` |
| `containerThroughput` | Container-level RU/s | `400` |
| `enablePublicAccess` | Allow public network access | `false` |
| `allowedIpRanges` | Allowed IP addresses/ranges | `[]` |

## Security Considerations

### Network Access

- Public access is **disabled by default**
- Configure `allowedIpRanges` for specific IP access
- Consider using Private Endpoints for production

### Authentication

- Use Azure AD authentication when possible
- Rotate access keys regularly
- Use least-privilege access principles

### Monitoring

- Review diagnostic logs regularly
- Monitor for unusual query patterns
- Set up alerts for high RU consumption

## Container Schema

### CVEs Container (`cvesContainer`)

- **Partition Key**: `/id`
- **Purpose**: Store CVE (Common Vulnerabilities and Exposures) data

### Identity Container (`identityContainer`)

- **Partition Key**: `/id`
- **Purpose**: Store identity and access management data

### Device Container (`deviceContainer`)

- **Partition Key**: `/id`
- **Purpose**: Store device security information

## Troubleshooting

### Common Issues

1. **Deployment Fails - Insufficient Permissions**
   - Ensure your account has `Contributor` role on the resource group
   - Check if Cosmos DB resource provider is registered

2. **Cannot Connect to Cosmos DB**
   - Verify IP address is in `allowedIpRanges`
   - Check if `enablePublicAccess` is set to `true` if needed

3. **High RU Consumption**
   - Review query patterns in diagnostic logs
   - Consider optimizing partition key strategy
   - Scale throughput if needed

### Getting Help

- Check Azure Activity Logs for deployment errors
- Review Cosmos DB metrics in Azure Portal
- Use diagnostic settings for detailed query analysis

## Cost Optimization

- Start with minimum throughput (400 RU/s) and scale as needed
- Use serverless tier for development/testing
- Monitor and optimize query patterns
- Consider autoscale for variable workloads

## Next Steps

1. Deploy the infrastructure using the provided scripts
2. Configure your application connection strings
3. Set up monitoring and alerting
4. Implement backup and disaster recovery procedures
5. Review and test security configurations

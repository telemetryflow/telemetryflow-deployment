# TelemetryFlow - TFState Bootstrap

Creates the S3 bucket + DynamoDB lock table used by **all** other TelemetryFlow
Terraform stacks for remote state.

## Bootstrap Workflow

> This is a chicken-and-egg stack: it creates the bucket that stores its own
> state. Apply with local state first, then migrate.

```
cd environment/telemetryflow/_tfstate

# 1. Init (local state, no backend yet)
terraform init

# 2. Create/select workspace
terraform workspace new default   # or: lab / staging / prod

# 3. Edit defaults in variable.tf (account id, bucket name, region)
#    then plan + apply
terraform plan
terraform apply

# 4. Migrate state into the bucket you just created
cp backend.tf.example backend.tf
# edit backend.tf -> match bucket/dynamodb_table/key from variable.tf
terraform init --migrate-state
```

## Verify

```
aws s3 ls s3://$TFSTATE_BUCKET/telemetryflow/
aws dynamodb describe-table --table-name $TFSTATE_DDB_TABLE
```

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**

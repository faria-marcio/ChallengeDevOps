import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as awsx from "@pulumi/awsx";
import * as random from "@pulumi/random";

const config = new pulumi.Config();
const containerPort = config.getNumber("containerPort") || 80;
const cpu = config.getNumber("cpu") || 512;
const memory = config.getNumber("memory") || 128;

// An ECS cluster to deploy into
const cluster = new aws.ecs.Cluster("cluster", {});

// An ALB to serve the container endpoint to the internet
const loadbalancer = new awsx.lb.ApplicationLoadBalancer("loadbalancer", {});

// An ECR repository to store our application's container image
const repo = new awsx.ecr.Repository("repo", {
  forceDelete: true,
});

const password = new random.RandomPassword("password", {
  length: 8,
  special: true,
  overrideSpecial: "!#$%&*()-_=+[]{}<>:?",
});

// A RDS database to be used by the app
const database = new aws.rds.Instance("database", {
  allocatedStorage: 10,
  engine: "mysql",
  engineVersion: "8.0.32",
  instanceClass: "db.t3.micro",
  dbName: "homesteaddb",
  port: 3306,
  username: "homestead",
  password: password.result,
  skipFinalSnapshot: true,
  storageType: "gp2",
});

// Build and publish our application's container image from the main app folder to the ECR repository
const image = new awsx.ecr.Image("image", {
  repositoryUrl: repo.url,
  path: "../../",
});

// Deploy an ECS Service on Fargate to host the application container
const service = new awsx.ecs.FargateService("service", {
  cluster: cluster.arn,
  assignPublicIp: true,
  taskDefinitionArgs: {
    container: {
      image: image.imageUri,
      cpu: cpu,
      memory: memory,
      essential: true,
      portMappings: [
        {
          containerPort: containerPort,
          targetGroup: loadbalancer.defaultTargetGroup,
        },
      ],
      environment: [
        {
          name: "APP_NAME",
          value: "Laravel",
        },
        {
          name: "APP_URL",
          value: "http://localhost",
        },
        {
          name: "DB_CONNECTION",
          value: "mysql",
        },
        {
          name: "DB_HOST",
          value: database.endpoint,
        },
        {
          name: "DB_PORT",
          value: `${database.port}`,
        },
        {
          name: "DB_DATABASE",
          value: database.dbName,
        },

        {
          name: "DB_USERNAME",
          value: database.username,
        },
        {
          name: "DB_PASSWORD",
          value: `${database.password}`,
        },
      ],
    },
  },
});

// The URL at which the container's HTTP endpoint will be available
export const url = pulumi.interpolate`http://${loadbalancer.loadBalancer.dnsName}`;

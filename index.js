const tracer = require('dd-trace').init({
    logInjection: true,
});
const express = require("express");
const app = express();
const { createLogger, format, transports } = require('winston');

const logger = createLogger({
    level: 'info',
    exitOnError: false,
    format: format.json(),
    transports: [new transports.File({ filename: `/shared-volume/logs/app.log` }),
    ],
});

app.get("/", (_, res) => {
    logger.info("Welcome!");
    res.sendStatus(200);
});

app.get("/hello", (_, res) => {
    logger.info("Hello!");
    metricPrefix = "nodejs-cloudrun";
    // Send three unique metrics, just so we're testing more than one single metric
    metricsToSend = ["sample_metric_1", "sample_metric_2", "sample_metric_3"];
    metricsToSend.forEach((metric) => {
        for (let i = 0; i < 20; i++) {
            tracer.dogstatsd.distribution(`${metricPrefix}.${metric}`, 1);
        }
    });
    res.status(200).json({ msg: "Sending metrics to Datadog" });
});

const port = process.env.PORT || 8080;
app.listen(port);
'use strict'

import AWS from 'aws-sdk'
import { parseStream } from '@fast-csv/parse'

const REGION = process.env.AWS_REGION

const s3 = new AWS.S3({ apiVersion: '2006-03-01', regin: REGION })

export const handler = async event => {
  try {
    if (event && event.Records) {
      for (let i = 0; i < event.Records.length; i++) {
        const { bucket, object } = event.Records[i].s3
        const { name } = bucket
        const { key } = object
        await getCsv(name, key)
        // TODO: send to SQS
      }
    }

    return { statusCode: 200 }
  } catch (err) {
    throw err
  }
}

// https://stackoverflow.com/questions/39861239/read-and-parse-csv-file-in-s3-without-downloading-the-entire-file
async function getCsv(name, key) {
  try {
    const params = { Bucket: name,  Key: key }
    const csvFile = s3.getObject(params).createReadStream()
    const parserFcn = new Promise((resolve, reject) => {
      parseStream(csvFile, { headers: true })
        .on('data', data => {
          console.log(data)
        })
        .on('end', function () {
          resolve('csv parse process finished')
        })
        .on('error', function () {
          reject('csv parse process failed')
        })
    })

    await parserFcn
  } catch(err) {
    throw err
  }
}
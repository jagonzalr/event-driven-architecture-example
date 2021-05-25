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
        const users = await getCsv(name, key)
        if (users) {
          // TODO: send to SQS
          console.log(JSON.stringify(users, null, 2))
        }
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
      let users = []
      parseStream(csvFile, { headers: true })
        .on('data', data => {
          users.push(data)
        })
        .on('end', function () {
          resolve(users)
        })
        .on('error', function () {
          reject(null)
        })
    })

    const users = await parserFcn
    return users
  } catch(err) {
    throw err
  }
}
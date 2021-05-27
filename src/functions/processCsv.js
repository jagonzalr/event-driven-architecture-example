'use strict'

import AWS from 'aws-sdk'
import { parseStream } from '@fast-csv/parse'
import { nanoid } from 'nanoid'

const BUFFER_QUEUE = process.env.BUFFER_QUEUE
const REGION = process.env.AWS_REGION

const s3 = new AWS.S3({ apiVersion: '2006-03-01', regin: REGION })
const sqs = new AWS.SQS({ apiVersion: '2012-11-05', region: REGION })

export const handler = async event => {
  if (event && event.Records) {
    const records = event.Records
    for (let i = 0; i < records.length; i++) {
      try {
        const { bucket, object } = records[i].s3
        const { name } = bucket
        const { key } = object
        const users = await parseCsv(name, key)
        if (users) {
          await sendUsersToQueue(users)
        }
      } catch(err) {
        console.log(err)
      }
    }
  }

  return { statusCode: 200 }
}

function chunkArray (arr, size = 10) {
  // https://gist.github.com/webinista/11240585
  return arr.reduce((chunks, obj, index) => {
    if (index % size === 0) {
      chunks.push([obj])
    } else {
      chunks[chunks.length - 1].push(obj)
    }

    return chunks
  }, [])
}

async function parseCsv(name, key) {
  // https://stackoverflow.com/questions/39861239/read-and-parse-csv-file-in-s3-without-downloading-the-entire-file
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

async function sendUsersToQueue(users) {
  const chunkUsers = chunkArray(users)
  for (let i = 0; i < chunkUsers.length; i++) {
    try {
      const batchUsers = chunkUsers[i]
      const entries = batchUsers.map(user => ({
        Id: nanoid(),
        MessageBody: JSON.stringify(user)
      }))

      const params = { Entries: entries, QueueUrl: BUFFER_QUEUE }
      await sqs.sendMessageBatch(params).promise()
    } catch(err) {
      console.log(err)
    }
  }
}
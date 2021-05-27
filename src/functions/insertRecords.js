'use strict'

import AWS from 'aws-sdk'

const REGION = process.env.AWS_REGION
const USERS_TABLE = process.env.USERS_TABLE

const db = new AWS.DynamoDB.DocumentClient({
  convertEmptyValues: true,
  region: REGION
})

export const handler = async event => {
  if (event && event.Records) {
    const records = event.Records
    for (let i = 0; i < records.length; i++) {
      try {
        const body = JSON.parse(records[i].body)
        await db.put({ TableName: USERS_TABLE, Item: body }).promise()
      } catch(err) {
        console.log(err)
      }
    }
  }

  return { statusCode: 200 }
}
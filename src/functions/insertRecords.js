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
    const putRequests = records.map(({ body }) => {
      return {
        PutRequest: {
          Item: JSON.parse(body)
        }
      }
    })
    
    const params = {
      RequestItems: {
        [USERS_TABLE]: putRequests
      }
    }

    await db.batchWrite(params).promise()
  }

  return { statusCode: 200 }
}
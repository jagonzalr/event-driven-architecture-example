'use strict'

import AWS from 'aws-sdk'

const FROM_EMAIL = process.env.FROM_EMAIL
const REGION = process.env.AWS_REGION

const sesv2 = new AWS.SESV2({ apiVersion: '2019-09-27', region: REGION })

export const handler = async event => {
  if (event && event.Records) {
    try {
      const records = event.Records
      const inserts = records.filter(({ eventName }) => eventName === 'INSERT')
      const multipeParams = inserts.reduce((acc, item) => {
        const { NewImage } = item.dynamodb
        const params = {
          FromEmailAddress: FROM_EMAIL,
          Destination: {
            ToAddresses: [NewImage['email']['S']]
          },
          Content: {
            Simple: {
              Body: {
                Html: {
                  Data: `<p>Welcome <strong>${NewImage['name']['S']}</strong>!</p><p>You have a new account.</p>`,
                  Charset: 'UTF-8'
                },
                Text: {
                  Data: `Welcome ${NewImage['name']['S']}! You have a new account.`,
                  Charset: 'UTF-8'
                }
              },
              Subject: {
                Data: `Welcome ${NewImage['name']['S']}!`,
                Charset: 'UTF-8'
              }
            }
          }
        }

        acc.push(params)
        return acc
      }, [])
      
      await Promise.all(multipeParams.map(params => sesv2.sendEmail(params).promise()))
    } catch(err) {
      console.log(err)
    }
  }

  return { statusCode: 200 }
}
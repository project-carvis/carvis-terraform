'use strict';
const aws = require('aws-sdk')
const sharp = require('sharp')
const s3 = new aws.S3()

exports.handler = async (event) => {

  // configuration
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
  }

  // vars
  const imageId = event.pathParameters.imageId
  const size = extractQueryParam(event, 'size', 'original', true)

  // check if image with id exists in any size
  if (!(await fileExists(imageId + '/original'))) {
    console.log('Original image does not exists', imageId)
    return {
      headers: corsHeaders,
      statusCode: 404
    }
  }

  // return image if exists in requested size
  if (await fileExists(`${imageId}/${size}`)) {
    console.log('Returning cached image', imageId, size)
    const url = getSignedUrl('getObject', `${imageId}/${size}`)
    return {
      headers: corsHeaders,
      statusCode: 200,
      body: JSON.stringify(url)
    }
  }

  // otherwise compress image
  console.log('Resizing image...', imageId, size)
  const originalImage = await getObject(`${imageId}/original`)
  const resizedImage = await resizeImage(originalImage, size)
  await putObject(`${imageId}/${size}`, resizedImage, originalImage.ContentType)
  const url = getSignedUrl('getObject', `${imageId}/${size}`)
  console.log('Finished resizing image', imageId, size)
  return {
    headers: corsHeaders,
    body: JSON.stringify(url)
  }
}

const fileExists = async (key) => {
  console.log('Checking if file exists...', key)
  try {
    await s3.headObject({
      Bucket: process.env.S3_BUCKET,
      Key: key
    }).promise();
    console.log('File exists', key)
    return true
  } catch (err) {
    console.log('File does not exist', key)
    return false
  }
}

const getObject = async (key) => {
  return await s3.getObject({
    Bucket: process.env.S3_BUCKET,
    Key: key
  }).promise()
}

const resizeImage = async (originalImage, size) => {
  return await sharp(originalImage.Body)
  .resize({ width: size })
  .toBuffer()
}

const putObject = async (key, resizedImage, contentType) => {
  await s3.putObject({
    Bucket: process.env.S3_BUCKET,
    Key: key,
    ContentType: contentType,
    Body: resizedImage
  }).promise()
}

const getSignedUrl = (method, key) => {
  return s3.getSignedUrl(method, {
    Bucket: process.env.S3_BUCKET,
    Key: key
  })
}

const extractQueryParam = (event, param, fallback, isInt) => {
  if (!event) {
    return fallback
  }

  if (!event.queryStringParameters) {
    return fallback
  }

  if (!event.queryStringParameters[param]) {
    return fallback
  }

  const value = event.queryStringParameters[param]
  return isInt ? parseInt(value) : value
}
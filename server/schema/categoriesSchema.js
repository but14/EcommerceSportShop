const mongoose = require("mongoose")
const Schema = mongoose.Schema
const categorySchema = new Schema({
    category_name   : { type : String , require : true , unique : true},
    category_slug   : { type : String , require : true , unique : true},
    category_img    : { type : String , default : '' },
    category_short_description : { type : String , default : ''},
    createdAt           : { type : Date , default : new Date() },
    updatedAt           : { type : Date }
})

categorySchema.index({ createdAt : 1 }) 

module.exports = mongoose.model("categories" , categorySchema)
import express from "express";
import router from "./chatbot.routes.js";

const moduleRouter = express.Router();
moduleRouter.use(router);

export default moduleRouter;
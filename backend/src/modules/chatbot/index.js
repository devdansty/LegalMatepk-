import express from "express";
import router from "./routes.js";

const moduleRouter = express.Router();
moduleRouter.use("/", router);

export default moduleRouter;
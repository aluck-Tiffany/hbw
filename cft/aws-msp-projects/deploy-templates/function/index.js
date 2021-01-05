const {
  deployTemplateMachine,
 } = process.env;

exports.handler = (event, context, callback) => {
  const updatedEvent = event;
  const templates = event.global.templates;
  const templatesIndex = (typeof event.global.templatesIndex === 'undefined') ?
  event.global.templates.length - 1 :
  event.global.templatesIndex;
  updatedEvent.local = {
    machine: {
      arn: deployTemplateMachine,
      input: {
        global: event.global,
        local: {
          template: templates[templatesIndex],
        },
      },
    },
  };
  updatedEvent.global.templatesIndex = templatesIndex - 1;
  callback(null, updatedEvent);
};

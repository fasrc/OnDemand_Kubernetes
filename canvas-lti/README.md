# Canvas Integration

## LTI Link Configuration

Courses that would like to request access to k8s should include the following custom property in their LTI link configuration:

```
custom_ondemand_plugin=k8s
```

For a complete example of an LTI link with the custom property, see [lti_k8s_config.xml](./lti_k8s_config.xml) ([xml schema](https://www.imsglobal.org/specs/lti/xml)).

## LTI Link Setup

### Prerequisites

- You must have the ability to update a Canvas course's settings to install the LTI link.
- You must have an XML configuration prepared such as [lti_k8s_config.xml](./lti_k8s_config.xml).

### Steps

1. Navigate to the Canvas Course Settings (e.g. https://canvas.harvard.edu/courses/XXX/settings).
2. Click **Add App**.
3. Configure as follows:
   - *Configuration Type:* Paste XML
   - *Name:* FAS OnDemand
   - *Consumer Key:* `(enter consumer key...)`
   - *Shared Secret:* `(enter shared secret...)`
   - *XML Configuration:* `(paste XML...)`

### Notes

This can also be scripted using the [Canvas API for External Tools](https://canvas.instructure.com/doc/api/external_tools.html).